// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title MockAggregator
 * @notice Simple swap executor used for testing SwapRouter integrations.
 */
contract MockAggregator {
    using SafeERC20 for IERC20;

    uint256 public rateNumerator;
    uint256 public rateDenominator;
    bool public deliverToReceiver;

    constructor(uint256 numerator, uint256 denominator) {
        require(denominator != 0, "MA: denominator zero");
        rateNumerator = numerator;
        rateDenominator = denominator;
    }

    function setRate(uint256 numerator, uint256 denominator) external {
        require(denominator != 0, "MA: denominator zero");
        rateNumerator = numerator;
        rateDenominator = denominator;
    }

    function setDeliverToReceiver(bool enabled) external {
        deliverToReceiver = enabled;
    }

    function swap(
        address sourceToken,
        address destinationToken,
        address receiver,
        uint256 amountIn,
        uint256 minAmountOut
    ) external returns (uint256 amountOut) {
        IERC20 source = IERC20(sourceToken);
        IERC20 destination = IERC20(destinationToken);

        source.safeTransferFrom(msg.sender, address(this), amountIn);

        amountOut = (amountIn * rateNumerator) / rateDenominator;
        require(amountOut >= minAmountOut, "MA: slippage");

        address payout = deliverToReceiver && receiver != address(0) ? receiver : msg.sender;
        destination.safeTransfer(payout, amountOut);

        return amountOut;
    }
}
