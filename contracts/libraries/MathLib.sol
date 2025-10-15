// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MathLib
 * @notice Safe math operations for rate conversions
 */
library MathLib {
    error DivisionByZero();
    error Overflow();

    uint256 constant PRECISION = 1e18;

    /**
     * @notice Multiply two numbers with precision
     * @param a First number
     * @param b Second number
     * @return result The result
     */
    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        if (denominator == 0) revert DivisionByZero();

        // Check for overflow
        uint256 prod = a * b;
        if (a != 0 && prod / a != b) revert Overflow();

        result = prod / denominator;
    }

    /**
     * @notice Calculate percentage of a value
     * @param value The value
     * @param percentage The percentage (in basis points, e.g., 100 = 1%)
     * @return result The calculated percentage
     */
    function percentage(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
        result = mulDiv(value, percentage, 10000);
    }

    /**
     * @notice Safe addition
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        if (c < a) revert Overflow();
        return c;
    }

    /**
     * @notice Safe subtraction
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "MathLib: subtraction underflow");
        return a - b;
    }
}
