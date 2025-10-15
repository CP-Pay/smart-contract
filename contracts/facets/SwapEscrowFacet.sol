// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibAppStorage.sol";
import "../libraries/TokenLib.sol";
import "../libraries/LibDiamond.sol";

/**
 * @title SwapEscrowFacet
 * @notice Handles deposits for off-chain swaps to CNGN
 * @dev Backend picks up deposits, swaps off-chain, and fulfills with CNGN
 */
contract SwapEscrowFacet {
    using TokenLib for address;

    error DepositFailed();
    error FulfillFailed();
    error InvalidAmount();
    error AlreadyFulfilled();

    uint8 constant DEPOSIT_STATUS_PENDING = 0;
    uint8 constant DEPOSIT_STATUS_FULFILLED = 1;
    uint8 constant DEPOSIT_STATUS_REFUNDED = 2;

    struct SwapDeposit {
        address user;
        address tokenIn;
        uint256 amountIn;
        uint256 amountCNGN;
        uint8 status;
        uint256 createdAt;
    }

    bytes32 constant SWAP_ESCROW_STORAGE_POSITION = keccak256("cppay.swapescrow.storage");

    struct SwapEscrowStorage {
        mapping(bytes32 => SwapDeposit) deposits;
    }

    function swapEscrowStorage() internal pure returns (SwapEscrowStorage storage ses) {
        bytes32 position = SWAP_ESCROW_STORAGE_POSITION;
        assembly {
            ses.slot := position
        }
    }

    event SwapDepositReceived(address indexed user, address indexed tokenIn, uint256 amountIn, bytes32 indexed refId);
    event SwapFulfilled(address indexed user, bytes32 indexed refId, uint256 amountCNGN);
    event SwapRefunded(address indexed user, bytes32 indexed refId, uint256 amountIn);

    /**
     * @notice Deposit tokens for off-chain swap to CNGN
     * @param tokenIn The input token address
     * @param amountIn The input amount
     * @param refId Unique reference ID for tracking
     */
    function depositAndLock(address tokenIn, uint256 amountIn, bytes32 refId) external {
        if (amountIn == 0) revert InvalidAmount();
        if (refId == bytes32(0)) revert LibAppStorage.InvalidRefId(refId);

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        SwapEscrowStorage storage ses = swapEscrowStorage();

        // Check if refId already exists
        if (ses.deposits[refId].user != address(0)) {
            revert AlreadyFulfilled();
        }

        // Verify supported token
        if (!s.isSupportedToken[tokenIn]) {
            revert LibAppStorage.UnsupportedToken(tokenIn);
        }

        // Transfer tokens from user to this contract
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);

        // Create deposit record
        ses.deposits[refId] = SwapDeposit({
            user: msg.sender,
            tokenIn: tokenIn,
            amountIn: amountIn,
            amountCNGN: 0,
            status: DEPOSIT_STATUS_PENDING,
            createdAt: block.timestamp
        });

        emit SwapDepositReceived(msg.sender, tokenIn, amountIn, refId);
        emit LibAppStorage.DepositReceived(msg.sender, tokenIn, amountIn, refId);
    }

    /**
     * @notice Fulfill swap by crediting CNGN after off-chain swap
     * @dev Only callable by contract owner (backend service)
     * @param refId The reference ID of the deposit
     * @param amountCNGN The CNGN amount to credit
     */
    function fulfillSwapToCNGN(bytes32 refId, uint256 amountCNGN) external {
        LibDiamond.enforceIsContractOwner();

        if (amountCNGN == 0) revert InvalidAmount();

        SwapEscrowStorage storage ses = swapEscrowStorage();
        SwapDeposit storage deposit = ses.deposits[refId];

        if (deposit.user == address(0)) {
            revert LibAppStorage.InvalidRefId(refId);
        }
        if (deposit.status != DEPOSIT_STATUS_PENDING) {
            revert AlreadyFulfilled();
        }

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        address cngn = s.cngn;

        // Update deposit
        deposit.amountCNGN = amountCNGN;
        deposit.status = DEPOSIT_STATUS_FULFILLED;

        // Transfer CNGN from treasury/owner to user
        // Backend must ensure treasury has sufficient CNGN
        cngn.safeTransfer(deposit.user, amountCNGN);

        emit SwapFulfilled(deposit.user, refId, amountCNGN);
    }

    /**
     * @notice Refund deposited tokens if swap fails
     * @dev Only callable by contract owner (backend service)
     * @param refId The reference ID of the deposit
     */
    function refundDeposit(bytes32 refId) external {
        LibDiamond.enforceIsContractOwner();

        SwapEscrowStorage storage ses = swapEscrowStorage();
        SwapDeposit storage deposit = ses.deposits[refId];

        if (deposit.user == address(0)) {
            revert LibAppStorage.InvalidRefId(refId);
        }
        if (deposit.status != DEPOSIT_STATUS_PENDING) {
            revert AlreadyFulfilled();
        }

        // Update status
        deposit.status = DEPOSIT_STATUS_REFUNDED;

        // Refund original tokens
        deposit.tokenIn.safeTransfer(deposit.user, deposit.amountIn);

        emit SwapRefunded(deposit.user, refId, deposit.amountIn);
    }

    /**
     * @notice Get deposit details
     * @param refId The reference ID
     * @return user The user address
     * @return tokenIn The input token
     * @return amountIn The input amount
     * @return amountCNGN The fulfilled CNGN amount
     * @return status The deposit status
     * @return createdAt The creation timestamp
     */
    function getDeposit(bytes32 refId)
        external
        view
        returns (address user, address tokenIn, uint256 amountIn, uint256 amountCNGN, uint8 status, uint256 createdAt)
    {
        SwapEscrowStorage storage ses = swapEscrowStorage();
        SwapDeposit storage deposit = ses.deposits[refId];

        return (deposit.user, deposit.tokenIn, deposit.amountIn, deposit.amountCNGN, deposit.status, deposit.createdAt);
    }
}
