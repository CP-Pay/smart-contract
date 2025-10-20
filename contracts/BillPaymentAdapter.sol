// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title BillPaymentAdapter
 * @notice Emits canonical events for downstream bill payment processors while enforcing provider controls and idempotency.
 */
contract BillPaymentAdapter is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    struct PaymentRequest {
        bytes32 providerCode;
        address account;
        uint256 amount;
        bytes32 refId;
        bytes metadata;
    }

    mapping(bytes32 => bool) public providerStatus;
    mapping(bytes32 => bool) public processedPayments;

    event ProviderStatusUpdated(bytes32 indexed providerCode, bool enabled, address indexed sender);
    event PaymentQueued(
        bytes32 indexed providerCode,
    bytes32 indexed refId,
        address indexed payer,
        address account,
        uint256 amount,
        bytes metadata,
        uint256 timestamp
    );

    constructor(address admin) {
        require(admin != address(0), "BPA: admin zero");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function setProvider(bytes32 providerCode, bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(providerCode != bytes32(0), "BPA: provider zero");
        providerStatus[providerCode] = enabled;
        emit ProviderStatusUpdated(providerCode, enabled, _msgSender());
    }

    function submitPayment(PaymentRequest calldata request) external nonReentrant whenNotPaused {
        require(request.providerCode != bytes32(0), "BPA: provider zero");
        require(providerStatus[request.providerCode], "BPA: provider disabled");
        require(request.account != address(0), "BPA: account zero");
        require(request.amount > 0, "BPA: zero amount");
        require(request.refId != bytes32(0), "BPA: reference zero");

        bytes32 key = keccak256(abi.encodePacked(request.providerCode, request.refId));
        require(!processedPayments[key], "BPA: duplicate");
        processedPayments[key] = true;

        emit PaymentQueued(
            request.providerCode,
            request.refId,
            _msgSender(),
            request.account,
            request.amount,
            request.metadata,
            block.timestamp
        );
    }

    function isProcessed(bytes32 providerCode, bytes32 refId) external view returns (bool) {
        return processedPayments[keccak256(abi.encodePacked(providerCode, refId))];
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
