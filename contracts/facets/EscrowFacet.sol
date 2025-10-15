// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibAppStorage.sol";
import "../libraries/TokenLib.sol";
import "../libraries/LibDiamond.sol";

/**
 * @title EscrowFacet
 * @notice Handles CNGN locking for fiat payouts and refunds
 * @dev Works with backend services for airtime, bills, and bank transfers
 */
contract EscrowFacet {
    using TokenLib for address;

    error LockFailed();
    error RefundFailed();
    error AlreadyProcessed();
    error InvalidAmount();
    error InvalidServiceCode();

    uint8 constant STATUS_NONE = 0;
    uint8 constant STATUS_LOCKED = 1;
    uint8 constant STATUS_COMPLETED = 2;
    uint8 constant STATUS_REFUNDED = 3;

    /**
     * @notice Lock CNGN for fiat off-ramp service
     * @param amount The amount of CNGN to lock
     * @param serviceCode The service identifier (e.g., "AIRTIME_MTNNIG", "BILL_DSTV")
     * @param refId Unique reference ID for this transaction
     */
    function lockCNGN(uint256 amount, bytes32 serviceCode, bytes32 refId) external {
        if (amount == 0) revert InvalidAmount();
        if (serviceCode == bytes32(0)) revert InvalidServiceCode();
        if (refId == bytes32(0)) revert LibAppStorage.InvalidRefId(refId);

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();

        // Check if refId already exists
        if (s.escrows[refId].status != STATUS_NONE) {
            revert AlreadyProcessed();
        }

        address cngn = s.cngn;
        if (cngn == address(0)) revert LockFailed();

        // Check balance
        uint256 balance = cngn.balanceOf(address(this));
        if (balance < amount) {
            revert LibAppStorage.InsufficientBalance(cngn, amount, balance);
        }

        // Create escrow record
        s.escrows[refId] = LibAppStorage.EscrowRecord({
            user: msg.sender,
            amountCNGN: amount,
            serviceCode: serviceCode,
            refId: refId,
            status: STATUS_LOCKED,
            createdAt: block.timestamp
        });

        // CNGN stays in the Diamond contract (already there)
        // Backend listens to this event and executes fiat payout

        emit LibAppStorage.CNGNLocked(msg.sender, amount, serviceCode, refId);
    }

    /**
     * @notice Refund CNGN to user if off-ramp fails
     * @dev Only callable by contract owner (backend service)
     * @param refId The reference ID of the transaction to refund
     */
    function refundCNGN(bytes32 refId) external {
        LibDiamond.enforceIsContractOwner();

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        LibAppStorage.EscrowRecord storage record = s.escrows[refId];

        if (record.status != STATUS_LOCKED) {
            revert LibAppStorage.EscrowNotLocked(refId);
        }

        address cngn = s.cngn;
        address user = record.user;
        uint256 amount = record.amountCNGN;

        // Update status
        record.status = STATUS_REFUNDED;

        // Transfer CNGN back to user
        cngn.safeTransfer(user, amount);

        emit LibAppStorage.CNGNRefunded(user, amount, refId);
    }

    /**
     * @notice Mark escrow as completed (called by backend after successful payout)
     * @param refId The reference ID of the completed transaction
     */
    function completeEscrow(bytes32 refId) external {
        LibDiamond.enforceIsContractOwner();

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        LibAppStorage.EscrowRecord storage record = s.escrows[refId];

        if (record.status != STATUS_LOCKED) {
            revert LibAppStorage.EscrowNotLocked(refId);
        }

        address cngn = s.cngn;
        address treasury = s.treasury;
        uint256 amount = record.amountCNGN;

        // Update status
        record.status = STATUS_COMPLETED;

        // Transfer CNGN to treasury (already spent on fiat side)
        cngn.safeTransfer(treasury, amount);
    }

    /**
     * @notice Get escrow details
     * @param refId The reference ID
     * record The escrow record
     */
    function getEscrow(bytes32 refId)
        external
        view
        returns (address user, uint256 amountCNGN, bytes32 serviceCode, uint8 status, uint256 createdAt)
    {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        LibAppStorage.EscrowRecord storage record = s.escrows[refId];

        return (record.user, record.amountCNGN, record.serviceCode, record.status, record.createdAt);
    }

    /**
     * @notice Check if escrow is locked
     * @param refId The reference ID
     * @return isLocked True if escrow is in locked state
     */
    function isEscrowLocked(bytes32 refId) external view returns (bool isLocked) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        return s.escrows[refId].status == STATUS_LOCKED;
    }
}
