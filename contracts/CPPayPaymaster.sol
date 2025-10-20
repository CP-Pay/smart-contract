// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@account-abstraction/contracts/core/BasePaymaster.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title CPPayPaymaster
 * @notice Paymaster enforcing NGN-denominated daily gas sponsorship budgets with tier-based limits.
 */
contract CPPayPaymaster is BasePaymaster, ReentrancyGuard, AccessControl {
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    uint256 public constant ONE_DAY = 1 days;
    uint256 public constant TIER1_MULTIPLIER = 1;

    uint256 public baseDailyBudgetKobo = 1_000 * 1e2; // ₦1000 default, stored in kobo
    uint256 public tier2Multiplier = 5_000; // Tier 2 => ₦5,000,000 budget
    uint256 public weiPerKobo; // conversion rate set by controller (wei per 0.01 NGN)

    bool public paymasterActive = true;

    struct UserBudget {
        uint256 usedWeiToday;
        uint64 lastReset;
        bool isTier2;
    }

    mapping(address => UserBudget) public userBudgets;

    event GasSponsored(address indexed account, uint256 actualWei, uint256 remainingWei);
    event DailyBudgetReset(address indexed account, uint256 newBudgetWei);
    event PaymasterActivationChanged(bool active);
    event ExchangeRateUpdated(uint256 weiPerKobo, uint256 timestamp);
    event BaseBudgetUpdated(uint256 newBudgetKobo);
    event TierMultiplierUpdated(uint256 newMultiplier);
    event UserTierUpdated(address indexed account, bool isTier2, uint256 multiplier);

    modifier onlyController() {
        require(
            hasRole(CONTROLLER_ROLE, msg.sender) || msg.sender == owner(),
            "CPPM: not controller"
        );
        _;
    }

    constructor(IEntryPoint entryPoint_) BasePaymaster(entryPoint_) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CONTROLLER_ROLE, msg.sender);
        
        // Initialize weiPerKobo to a sensible default if not set
        // 1 wei per kobo means 100 wei per NGN (1 kobo = 0.01 NGN)
        // This ensures baseDailyBudgetKobo (1000 kobo = ₦10) = 100,000 wei
        if (weiPerKobo == 0) {
            weiPerKobo = 100; // 100 wei per kobo = 10,000 wei per ₦10
        }
    }

    /// @inheritdoc BasePaymaster
    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32,
        uint256 maxCost
    ) internal override returns (bytes memory context, uint256 validationData) {
        require(paymasterActive, "CPPM: inactive");
        require(weiPerKobo > 0, "CPPM: rate not set");

        address account = userOp.sender;
        UserBudget storage budget = userBudgets[account];
        _maybeReset(account, budget);

        uint256 limitWei = _dailyLimitWei(budget);
        uint256 remaining = _remainingWei(budget, limitWei);
        require(remaining >= maxCost, "CPPM: budget exceeded");

        require(_currentDeposit() >= maxCost, "CPPM: low deposit");

        context = abi.encode(account);
        validationData = 0;
    }

    /// @inheritdoc BasePaymaster
    function _postOp(
        PostOpMode,
        bytes calldata context,
        uint256 actualGasCost
    ) internal override {
        address account = abi.decode(context, (address));
        UserBudget storage budget = userBudgets[account];
        _maybeReset(account, budget);

        budget.usedWeiToday += actualGasCost;

        uint256 limitWei = _dailyLimitWei(budget);
        uint256 remaining = _remainingWei(budget, limitWei);
        emit GasSponsored(account, actualGasCost, remaining);
    }

    /// @notice Returns current gas allowance details for an account.
    /// @dev Auto-initializes lastReset if user is new (lastReset == 0)
    function getGasStatus(address account)
        external
        view
        returns (
            uint256 dailyLimitWei,
            uint256 usedWei,
            uint256 remainingWei,
            uint64 lastReset,
            bool isTier2
        )
    {
        UserBudget memory budget = userBudgets[account];
        
        // Auto-initialize lastReset if user is new
        if (budget.lastReset == 0) {
            budget.lastReset = uint64(block.timestamp);
        }
        
        uint256 limitWei = _dailyLimitWei(budget);
        uint256 used = budget.usedWeiToday;
        if (_shouldReset(budget)) {
            used = 0;
        }
        uint256 remaining = limitWei > used ? limitWei - used : 0;
        return (limitWei, used, remaining, budget.lastReset, budget.isTier2);
    }

    /// @notice Update wei-per-kobo conversion rate (controller only).
    function updateExchangeRate(uint256 newWeiPerKobo) external onlyController {
        require(newWeiPerKobo > 0, "CPPM: invalid rate");
        weiPerKobo = newWeiPerKobo;
        emit ExchangeRateUpdated(newWeiPerKobo, block.timestamp);
    }

    /// @notice Update base daily budget (kobo) (owner only).
    function updateBaseDailyBudget(uint256 newBudgetKobo) external onlyOwner {
        require(newBudgetKobo > 0, "CPPM: invalid budget");
        baseDailyBudgetKobo = newBudgetKobo;
        emit BaseBudgetUpdated(newBudgetKobo);
    }

    /// @notice Update Tier 2 multiplier (owner only).
    function updateTier2Multiplier(uint256 newMultiplier) external onlyOwner {
        require(newMultiplier >= TIER1_MULTIPLIER, "CPPM: bad multiplier");
        tier2Multiplier = newMultiplier;
        emit TierMultiplierUpdated(newMultiplier);
    }

    /// @notice Set Tier 2 status for account (controller or owner).
    function setUserTier(address account, bool isTier2) external onlyController {
        UserBudget storage budget = userBudgets[account];
        budget.isTier2 = isTier2;
        emit UserTierUpdated(account, isTier2, isTier2 ? tier2Multiplier : TIER1_MULTIPLIER);
    }

    /// @notice Manually reset user's daily spending (controller or owner only).
    /// @dev Useful for admin operations or testing without waiting 24 hours.
    function resetUserDailySpending(address account) external onlyController {
        UserBudget storage budget = userBudgets[account];
        budget.usedWeiToday = 0;
        budget.lastReset = uint64(block.timestamp);
        emit DailyBudgetReset(account, _dailyLimitWei(budget));
    }

    /// @notice Toggle paymaster activity (owner only).
    function setPaymasterActive(bool active) external onlyOwner {
        paymasterActive = active;
        emit PaymasterActivationChanged(active);
    }

    /// @notice Return current EntryPoint deposit for this paymaster.
    function paymasterDeposit() external view returns (uint256) {
        return _currentDeposit();
    }

    /// @inheritdoc AccessControl
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _dailyLimitWei(UserBudget memory budget) internal view returns (uint256) {
        uint256 baseWei = baseDailyBudgetKobo * weiPerKobo;
        uint256 multiplier = budget.isTier2 ? tier2Multiplier : TIER1_MULTIPLIER;
        return baseWei * multiplier;
    }

    function _remainingWei(UserBudget memory budget, uint256 limitWei) internal pure returns (uint256) {
        if (limitWei <= budget.usedWeiToday) {
            return 0;
        }
        return limitWei - budget.usedWeiToday;
    }

    function _maybeReset(address account, UserBudget storage budget) internal {
        // Initialize new user's lastReset if not set
        if (budget.lastReset == 0) {
            budget.lastReset = uint64(block.timestamp);
            emit DailyBudgetReset(account, _dailyLimitWei(budget));
        } else if (_shouldReset(budget)) {
            budget.usedWeiToday = 0;
            budget.lastReset = uint64(block.timestamp);
            emit DailyBudgetReset(account, _dailyLimitWei(budget));
        }
    }

    function _shouldReset(UserBudget memory budget) internal view returns (bool) {
        return block.timestamp >= uint256(budget.lastReset) + ONE_DAY;
    }

    function _currentDeposit() internal view returns (uint256) {
        return entryPoint.getDepositInfo(address(this)).deposit;
    }
}