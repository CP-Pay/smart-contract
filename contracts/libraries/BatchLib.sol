// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BatchLib
 * @notice Utilities for batch execution operations
 */
library BatchLib {
    error InvalidBatchSize();
    error BatchExecutionFailed(uint256 index);

    uint256 constant MAX_BATCH_SIZE = 20;

    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    /**
     * @notice Validate batch size
     * @param size The batch size to validate
     */
    function validateBatchSize(uint256 size) internal pure {
        if (size == 0 || size > MAX_BATCH_SIZE) {
            revert InvalidBatchSize();
        }
    }

    /**
     * @notice Execute batch of calls atomically (all or nothing)
     * @param calls Array of calls to execute
     */
    function executeAtomic(Call[] memory calls) internal {
        validateBatchSize(calls.length);

        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = calls[i].target.call{value: calls[i].value}(calls[i].data);

            if (!success) {
                // Revert entire batch
                if (result.length > 0) {
                    assembly {
                        revert(add(result, 32), mload(result))
                    }
                } else {
                    revert BatchExecutionFailed(i);
                }
            }
        }
    }

    /**
     * @notice Execute batch of calls sequentially (continue on failure)
     * @param calls Array of calls to execute
     * @return results Array of execution results
     */
    function executeSequential(Call[] memory calls) internal returns (bool[] memory results) {
        validateBatchSize(calls.length);
        results = new bool[](calls.length);

        for (uint256 i = 0; i < calls.length; i++) {
            (bool success,) = calls[i].target.call{value: calls[i].value}(calls[i].data);
            results[i] = success;
        }

        return results;
    }
}
