// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LibAppStorage
 * @notice Centralized application storage library for CPPay Diamond
 * @dev Uses fixed storage slots to prevent collisions across facets
 */
library LibAppStorage {
    bytes32 constant APP_STORAGE_POSITION = keccak256("cppay.app.storage");

    struct UserTier {
        uint8 tier;
        bool usedTrial;
        uint256 lastUpdated;
    }

    struct GasUsage {
        uint256 monthlyLimit;
        uint256 usedThisMonth;
        uint256 lastReset;
        uint256 dailyTransactionCount; // Number of sponsored txs today
        uint256 lastDailyReset; // Last time daily count was reset
    }

    struct SessionKey {
        address key;
        uint256 expiry;
        bytes4[] selectors;
        uint256 perTxGasCap;
        uint256 spentAmount;
        bool revoked;
    }

    struct EscrowRecord {
        address user;
        uint256 amountCNGN;
        bytes32 serviceCode;
        bytes32 refId;
        uint8 status; // 0: None, 1: Locked, 2: Completed, 3: Refunded
        uint256 createdAt;
    }

    struct AppStorage {
        // Treasury and system addresses
        address treasury;
        address entryPoint;
        address cngn;
        // Supported tokens
        address[] supportedTokens;
        mapping(address => bool) isSupportedToken;
        // User tiers
        mapping(address => UserTier) userTiers;
        // Gas sponsorship
        mapping(address => GasUsage) gasUsage;
        // Session keys
        mapping(bytes32 => SessionKey) sessionKeys;
        mapping(address => bytes32[]) userSessionKeys;
        // Escrow & off-ramp
        mapping(bytes32 => EscrowRecord) escrows;
        // Import tracking
        mapping(address => address) importedAddresses; // diamond => imported EOA
        mapping(address => bool) isImportedWallet; // diamond => is imported
        // Reserved for future upgrades
        uint256[48] __gap;
    }

    function appStorage() internal pure returns (AppStorage storage as_) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            as_.slot := position
        }
    }

    // Custom errors
    error NotContractOwner();
    error UnsupportedToken(address token);
    error GasLimitExceeded(uint256 attempted, uint256 remaining);
    error SessionKeyExpired(bytes32 keyId);
    error SelectorNotAllowed(bytes4 selector);
    error InsufficientBalance(address token, uint256 required, uint256 available);
    error InvalidRefId(bytes32 refId);
    error EscrowNotLocked(bytes32 refId);
    error Unauthorized();

    // Events
    event SessionKeyCreated(address indexed user, bytes32 indexed keyId, uint256 expiry);
    event SessionKeyRevoked(address indexed user, bytes32 indexed keyId);
    event Sponsorship(address indexed user, uint256 gas, bool sponsored);
    event MonthlyReset(address indexed user, uint256 newLimit);
    event CNGNLocked(address indexed user, uint256 amount, bytes32 serviceCode, bytes32 refId);
    event CNGNRefunded(address indexed user, uint256 amount, bytes32 refId);
    event DepositReceived(address indexed user, address tokenIn, uint256 amountIn, bytes32 refId);
}
