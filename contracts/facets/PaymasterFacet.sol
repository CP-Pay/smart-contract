// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IPaymaster.sol";

contract PaymasterFacet is IPaymaster {
    bytes32 constant PAYMASTER_STORAGE_POSITION = keccak256("cppay.paymaster.storage");

    struct UserTier {
        uint8 tier;
        uint256 dailySponsorshipLimit;
        bool enabled;
    }

    struct DailyLimit {
        uint256 amount;
        uint256 resetTime;
    }

    struct PaymasterStorage {
        address entryPoint;
        address owner;
        uint256 depositedFunds;
        mapping(address => UserTier) userTiers;
        mapping(address => uint256) sponsoredAmounts;
        mapping(address => bool) acceptedTokens;
        mapping(address => uint256) tokenPrices;
        mapping(address => DailyLimit) dailyLimits;
    }

    function paymasterStorage() internal pure returns (PaymasterStorage storage ps) {
        bytes32 position = PAYMASTER_STORAGE_POSITION;
        assembly {
            ps.slot := position
        }
    }

    uint256 constant BASIC_DAILY_LIMIT = 0.01 ether;
    uint256 constant PREMIUM_DAILY_LIMIT = 0.1 ether;
    uint256 constant ENTERPRISE_DAILY_LIMIT = 1 ether;
    uint256 constant MAX_TRANSACTION_SPONSORSHIP = 0.005 ether;

    event GasSponsored(address indexed user, uint256 gasAmount, uint256 actualGasCost);
    event UserTierUpdated(address indexed user, uint8 tier);
    event TokenAccepted(address indexed token, bool accepted);
    event FundsDeposited(address indexed from, uint256 amount);
    event FundsWithdrawn(address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == paymasterStorage().owner, "Paymaster: not owner");
        _;
    }

    modifier onlyEntryPoint() {
        require(msg.sender == paymasterStorage().entryPoint, "Paymaster: not EntryPoint");
        _;
    }

    function initializePaymaster(address _entryPoint, address _owner) external {
        PaymasterStorage storage ps = paymasterStorage();
        require(ps.owner == address(0), "Already initialized");
        ps.entryPoint = _entryPoint;
        ps.owner = _owner;
    }

    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 /* userOpHash */,
        uint256 maxCost
    ) external override onlyEntryPoint returns (bytes memory context, uint256 validationData) {
        PaymasterStorage storage ps = paymasterStorage();
        address user = userOp.sender;

        bool shouldSponsor = _shouldSponsorUser(user, maxCost);

        if (shouldSponsor) {
            require(address(this).balance >= maxCost, "Paymaster: insufficient funds");

            DailyLimit storage limit = ps.dailyLimits[user];
            if (block.timestamp >= limit.resetTime) {
                limit.amount = 0;
                limit.resetTime = block.timestamp + 1 days;
            }
            limit.amount += maxCost;

            ps.sponsoredAmounts[user] += maxCost;

            context = abi.encode(user, maxCost, true);
            return (context, 0);
        } else {
            address token = address(bytes20(userOp.paymasterAndData[20:40]));
            require(ps.acceptedTokens[token], "Paymaster: token not accepted");

            uint256 tokenAmount = _calculateTokenAmount(token, maxCost);
            IERC20(token).transferFrom(user, address(this), tokenAmount);

            context = abi.encode(user, maxCost, false);
            return (context, 0);
        }
    }

    function postOp(
        PostOpMode /* mode */,
        bytes calldata context,
        uint256 actualGasCost
    ) external override onlyEntryPoint {
        (address user, uint256 maxCost, bool wasSponsored) = abi.decode(context, (address, uint256, bool));

        if (wasSponsored) {
            emit GasSponsored(user, maxCost, actualGasCost);
        }
    }

    function _shouldSponsorUser(address user, uint256 cost) internal view returns (bool) {
        PaymasterStorage storage ps = paymasterStorage();
        UserTier storage tier = ps.userTiers[user];

        if (!tier.enabled) return false;
        if (cost > MAX_TRANSACTION_SPONSORSHIP) return false;

        DailyLimit storage limit = ps.dailyLimits[user];
        uint256 currentDaily = limit.amount;
        if (block.timestamp >= limit.resetTime) {
            currentDaily = 0;
        }

        return (currentDaily + cost) <= tier.dailySponsorshipLimit;
    }

    function _calculateTokenAmount(address token, uint256 gasCost) internal view returns (uint256) {
        PaymasterStorage storage ps = paymasterStorage();
        uint256 tokenPrice = ps.tokenPrices[token];
        require(tokenPrice > 0, "Paymaster: no price for token");
        return (gasCost * 1e18) / tokenPrice;
    }

    function setUserTier(address user, uint8 tier, bool enabled) external onlyOwner {
        PaymasterStorage storage ps = paymasterStorage();
        
        uint256 dailyLimit;
        if (tier == 1) {
            dailyLimit = BASIC_DAILY_LIMIT;
        } else if (tier == 2) {
            dailyLimit = PREMIUM_DAILY_LIMIT;
        } else if (tier == 3) {
            dailyLimit = ENTERPRISE_DAILY_LIMIT;
        }

        ps.userTiers[user] = UserTier({tier: tier, dailySponsorshipLimit: dailyLimit, enabled: enabled});

        emit UserTierUpdated(user, tier);
    }

    function setAcceptedToken(address token, bool accepted, uint256 priceInWei) external onlyOwner {
        PaymasterStorage storage ps = paymasterStorage();
        ps.acceptedTokens[token] = accepted;
        if (accepted) {
            ps.tokenPrices[token] = priceInWei;
        }
        emit TokenAccepted(token, accepted);
    }

    function deposit() external payable onlyOwner {
        PaymasterStorage storage ps = paymasterStorage();
        ps.depositedFunds += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount, address payable to) external onlyOwner {
        PaymasterStorage storage ps = paymasterStorage();
        require(amount <= ps.depositedFunds, "Paymaster: insufficient balance");
        ps.depositedFunds -= amount;
        to.transfer(amount);
        emit FundsWithdrawn(to, amount);
    }

    function getUserTier(address user) external view returns (uint8 tier, uint256 dailyLimit, bool enabled) {
        UserTier storage userTier = paymasterStorage().userTiers[user];
        return (userTier.tier, userTier.dailySponsorshipLimit, userTier.enabled);
    }

    function getSponsoredAmount(address user) external view returns (uint256) {
        return paymasterStorage().sponsoredAmounts[user];
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
