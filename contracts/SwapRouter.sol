// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title SwapRouter
 * @notice Thin proxy around approved aggregators (e.g. 0x, 1inch) with slippage protection and audit trails.
 */
contract SwapRouter is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    struct SwapRequest {
        address aggregator;
        address sourceToken;
        address destinationToken;
        address recipient;
        uint256 amountIn;
        uint256 minAmountOut;
        bytes32 refId;
    }

    mapping(address => bool) public approvedAggregators;

    event AggregatorStatusUpdated(address indexed aggregator, bool approved, address indexed sender);
    event SwapExecuted(
        address indexed initiator,
        address indexed recipient,
        address indexed sourceToken,
        address destinationToken,
        uint256 amountIn,
        uint256 amountOut,
        address aggregator,
        bytes32 refId,
        bytes32 metadataHash
    );

    constructor(address admin) {
        require(admin != address(0), "SR: admin zero");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function setAggregator(address aggregator, bool approved) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(aggregator != address(0), "SR: agg zero");
        approvedAggregators[aggregator] = approved;
        emit AggregatorStatusUpdated(aggregator, approved, _msgSender());
    }

    function executeSwap(
        SwapRequest calldata request,
        bytes calldata callData,
        bytes calldata metadata
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        address initiator = _msgSender();
        address recipient = request.recipient == address(0) ? initiator : request.recipient;
        bytes32 metadataHash = metadata.length == 0 ? bytes32(0) : keccak256(metadata);

        amountOut = _processSwap(initiator, recipient, request, callData);

        require(amountOut >= request.minAmountOut, "SR: slippage");

        bytes32 refId = request.refId;
        address aggregator = request.aggregator;
        address sourceToken = request.sourceToken;
        address destinationToken = request.destinationToken;
        uint256 amountIn = request.amountIn;

        emit SwapExecuted(
            initiator,
            recipient,
            sourceToken,
            destinationToken,
            amountIn,
            amountOut,
            aggregator,
            refId,
            metadataHash
        );
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function rescueTokens(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(0) && to != address(0), "SR: zero addr");
        IERC20(token).safeTransfer(to, amount);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _processSwap(
        address initiator,
        address recipient,
        SwapRequest calldata request,
        bytes calldata callData
    ) private returns (uint256 amountOut) {
        address aggregator = request.aggregator;
        address sourceToken = request.sourceToken;
        address destinationToken = request.destinationToken;
        uint256 amountIn = request.amountIn;
        bytes32 refId = request.refId;

        require(aggregator != address(0), "SR: agg zero");
        require(approvedAggregators[aggregator], "SR: agg not approved");
        require(sourceToken != address(0), "SR: src zero");
        require(destinationToken != address(0), "SR: dst zero");
        require(amountIn > 0, "SR: zero amount");
        require(refId != bytes32(0), "SR: ref zero");

        IERC20 source = IERC20(sourceToken);
        IERC20 destination = IERC20(destinationToken);
        bytes memory result;

        {
            uint256 balanceBeforeRouter = destination.balanceOf(address(this));

            source.safeTransferFrom(initiator, address(this), amountIn);

            source.safeApprove(aggregator, 0);
            source.safeApprove(aggregator, amountIn);

            result = _callAggregator(aggregator, callData);

            source.safeApprove(aggregator, 0);

            uint256 routerReceived = destination.balanceOf(address(this)) - balanceBeforeRouter;
            if (routerReceived > 0) {
                destination.safeTransfer(recipient, routerReceived);
            }
            amountOut = routerReceived;
        }

        if (amountOut == 0 && result.length >= 32) {
            amountOut = abi.decode(result, (uint256));
        }

        return amountOut;
    }

    function _callAggregator(address aggregator, bytes calldata callData) private returns (bytes memory) {
        (bool success, bytes memory response) = aggregator.call(callData);
        require(success, _revertMessage(response));
        return response;
    }

    function _revertMessage(bytes memory result) private pure returns (string memory) {
        if (result.length < 68) {
            return "SR: aggregator fail";
        }
        assembly {
            result := add(result, 0x04)
        }
        return abi.decode(result, (string));
    }
}
