// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IPaymaster.sol";
import "../libraries/LibAppStorage.sol";
import "../libraries/LibDiamond.sol";

contract PaymasterFacet is IPaymaster {
    bytes32 constant PAYMASTER_STORAGE_POSITION = keccak256("cppay.paymaster.storage");

    struct PaymasterStorage {
        address entryPoint;
        uint256 depositedFunds;
        mapping(address => bool) acceptedTokens;
        mapping(address => uint256) tokenPrices;
    }

    function paymasterStorage() internal pure returns (PaymasterStorage storage ps) {
        bytes32 position = PAYMASTER_STORAGE_POSITION;
        assembly {
            ps.slot := position
        }
    }

    // Sponsorship thresholds
    // Transactions under ₦10,000 (~0.005 ETH) are sponsored
    // Max 10 transactions per day under this threshold
    uint256 constant MAX_TRANSACTION_SPONSORSHIP = 0.005 ether; // ₦10,000 @ 2M Naira/ETH
    uint256 constant MAX_DAILY_SPONSORED_TXS = 10; // Max 10 sponsored txs per day
    uint256 constant MONTHLY_LIMIT_TIER_1 = 0.05 ether; // ~₦100,000/month (fallback)

    event GasSponsored(address indexed user, uint256 gasAmount, uint256 actualGasCost, uint256 dailyCount);
    event DailyLimitReached(address indexed user, uint256 transactionCount);
    event FundsDeposited(address indexed from, uint256 amount);
    event FundsWithdrawn(address indexed to, uint256 amount);
    event TokenAccepted(address indexed token, bool accepted);

    modifier onlyEntryPoint() {
        require(msg.sender == paymasterStorage().entryPoint, "Paymaster: not EntryPoint");
        _;
    }

    function initializePaymaster(address _entryPoint) external {
        PaymasterStorage storage ps = paymasterStorage();
        require(ps.entryPoint == address(0), "Already initialized");
        ps.entryPoint = _entryPoint;
    }

    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32,
        /* userOpHash */
        uint256 maxCost
    ) external override onlyEntryPoint returns (bytes memory context, uint256 validationData) {
        PaymasterStorage storage ps = paymasterStorage();
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        address user = userOp.sender;

        bool shouldSponsor = _shouldSponsorUser(user, maxCost);

        if (shouldSponsor) {
            require(address(this).balance >= maxCost, "Paymaster: insufficient funds");

            LibAppStorage.GasUsage storage usage = s.gasUsage[user];

            // Reset daily count if new day
            if (block.timestamp >= usage.lastDailyReset + 1 days) {
                usage.dailyTransactionCount = 0;
                usage.lastDailyReset = block.timestamp;
            }

            // Reset monthly usage if new month
            if (block.timestamp >= usage.lastReset + 30 days) {
                usage.usedThisMonth = 0;
                usage.lastReset = block.timestamp;
                emit LibAppStorage.MonthlyReset(user, usage.monthlyLimit);
            }

            // Increment daily transaction count
            usage.dailyTransactionCount += 1;
            usage.usedThisMonth += maxCost;

            context = abi.encode(user, maxCost, true);
            emit LibAppStorage.Sponsorship(user, maxCost, true);
            return (context, 0);
        } else {
            // Fallback: user pays with ERC-20 token
            address token = address(bytes20(userOp.paymasterAndData[20:40]));
            require(ps.acceptedTokens[token], "Paymaster: token not accepted");

            uint256 tokenAmount = _calculateTokenAmount(token, maxCost);
            IERC20(token).transferFrom(user, address(this), tokenAmount);

            context = abi.encode(user, maxCost, false);
            emit LibAppStorage.Sponsorship(user, maxCost, false);
            return (context, 0);
        }
    }

    function postOp(
        PostOpMode,
        /* mode */
        bytes calldata context,
        uint256 actualGasCost
    ) external override onlyEntryPoint {
        (address user, uint256 maxCost, bool wasSponsored) = abi.decode(context, (address, uint256, bool));

        if (wasSponsored) {
            LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
            uint256 dailyCount = s.gasUsage[user].dailyTransactionCount;
            emit GasSponsored(user, maxCost, actualGasCost, dailyCount);
        }
    }

    function _shouldSponsorUser(address user, uint256 cost) internal view returns (bool) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();

        // Rule 1: Transaction must be under ₦10,000 (~0.005 ETH)
        if (cost > MAX_TRANSACTION_SPONSORSHIP) return false;

        LibAppStorage.GasUsage storage usage = s.gasUsage[user];

        // Rule 2: Check daily transaction count (max 10 per day)
        uint256 currentDailyCount = usage.dailyTransactionCount;

        // Reset daily count if day has passed
        if (block.timestamp >= usage.lastDailyReset + 1 days) {
            currentDailyCount = 0;
        }

        // If user already made 10 sponsored transactions today, deny sponsorship
        if (currentDailyCount >= MAX_DAILY_SPONSORED_TXS) {
            return false;
        }

        // Rule 3: Check monthly usage (secondary check)
        uint256 currentMonthly = usage.usedThisMonth;

        // Reset if month has passed
        if (block.timestamp >= usage.lastReset + 30 days) {
            currentMonthly = 0;
        }

        // Check if user has monthly limit set (default to MONTHLY_LIMIT_TIER_1)
        uint256 monthlyLimit = usage.monthlyLimit;
        if (monthlyLimit == 0) {
            monthlyLimit = MONTHLY_LIMIT_TIER_1;
        }

        return (currentMonthly + cost) <= monthlyLimit;
    }

    function _calculateTokenAmount(address token, uint256 gasCost) internal view returns (uint256) {
        PaymasterStorage storage ps = paymasterStorage();
        uint256 tokenPrice = ps.tokenPrices[token];
        require(tokenPrice > 0, "Paymaster: no price for token");
        return (gasCost * 1e18) / tokenPrice;
    }

    function setMonthlyLimit(address user, uint256 newLimit) external {
        LibDiamond.enforceIsContractOwner();

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        s.gasUsage[user].monthlyLimit = newLimit;

        emit LibAppStorage.MonthlyReset(user, newLimit);
    }

    function resetMonthlyUsage(address user) external {
        LibDiamond.enforceIsContractOwner();

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        LibAppStorage.GasUsage storage usage = s.gasUsage[user];

        usage.usedThisMonth = 0;
        usage.lastReset = block.timestamp;

        emit LibAppStorage.MonthlyReset(user, usage.monthlyLimit);
    }

    function setAcceptedToken(address token, bool accepted, uint256 priceInWei) external {
        LibDiamond.enforceIsContractOwner();

        PaymasterStorage storage ps = paymasterStorage();
        ps.acceptedTokens[token] = accepted;
        if (accepted) {
            ps.tokenPrices[token] = priceInWei;
        }
        emit TokenAccepted(token, accepted);
    }

    function depositNative() external payable {
        LibDiamond.enforceIsContractOwner();

        PaymasterStorage storage ps = paymasterStorage();
        ps.depositedFunds += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    function withdrawNative(uint256 amount) external {
        LibDiamond.enforceIsContractOwner();

        PaymasterStorage storage ps = paymasterStorage();
        require(amount <= ps.depositedFunds, "Paymaster: insufficient balance");
        ps.depositedFunds -= amount;
        payable(msg.sender).transfer(amount);
        emit FundsWithdrawn(msg.sender, amount);
    }

    function getGasUsage(address user)
        external
        view
        returns (
            uint256 monthlyLimit,
            uint256 usedThisMonth,
            uint256 lastReset,
            uint256 dailyTransactionCount,
            uint256 lastDailyReset
        )
    {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        LibAppStorage.GasUsage storage usage = s.gasUsage[user];

        monthlyLimit = usage.monthlyLimit == 0 ? MONTHLY_LIMIT_TIER_1 : usage.monthlyLimit;
        usedThisMonth = usage.usedThisMonth;
        lastReset = usage.lastReset;
        dailyTransactionCount = usage.dailyTransactionCount;
        lastDailyReset = usage.lastDailyReset;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function isTokenAccepted(address token) external view returns (bool) {
        return paymasterStorage().acceptedTokens[token];
    }

    function getRemainingDailyTransactions(address user) external view returns (uint256) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        LibAppStorage.GasUsage storage usage = s.gasUsage[user];

        uint256 currentCount = usage.dailyTransactionCount;

        // Reset count if day has passed
        if (block.timestamp >= usage.lastDailyReset + 1 days) {
            currentCount = 0;
        }

        if (currentCount >= MAX_DAILY_SPONSORED_TXS) {
            return 0;
        }

        return MAX_DAILY_SPONSORED_TXS - currentCount;
    }
}
