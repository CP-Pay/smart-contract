// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibAppStorage.sol";
import "../libraries/LibDiamond.sol";

/**
 * @title InitDiamond
 * @notice Initialization contract for Diamond proxy
 * @dev Called during Diamond deployment to set up initial state
 */
contract InitDiamond {
    event DiamondInitialized(
        address indexed owner,
        address entryPoint,
        address treasury
    );

    /**
     * @notice Initialize the Diamond with full configuration
     * @param owner The owner address
     * @param entryPoint The ERC-4337 EntryPoint address
     * @param treasury The treasury address
     * @param cngn The CNGN token address
     */
    function init(
        address owner,
        address entryPoint,
        address treasury,
        address cngn
    ) external {
        // Set Diamond owner
        LibDiamond.setContractOwner(owner);

        // Initialize app storage
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        s.treasury = treasury;
        s.entryPoint = entryPoint;
        s.cngn = cngn;

        // Initialize account storage
        bytes32 accountPosition = keccak256("cppay.account.storage");
        assembly {
            let ptr := accountPosition
            sstore(ptr, owner) // Store owner at position 0
            sstore(add(ptr, 1), entryPoint) // Store entryPoint at position 1
        }

        // Initialize Paymaster storage
        bytes32 paymasterPosition = keccak256("cppay.paymaster.storage");
        assembly {
            sstore(paymasterPosition, entryPoint) // Store entryPoint for paymaster
        }

        // Initialize Utility storage (set owner as first admin)
        bytes32 utilityPosition = keccak256("cppay.utility.storage");
        assembly {
            // paused = false (default)
            sstore(add(utilityPosition, 1), 1) // initialized = true
            // admins[owner] = true (need to calculate mapping slot)
            mstore(0x00, owner)
            mstore(0x20, add(utilityPosition, 2)) // admins mapping is at position 2
            let adminSlot := keccak256(0x00, 0x40)
            sstore(adminSlot, 1) // Set owner as admin
            // emergencyWithdrawalDelay = 48 hours
            sstore(add(utilityPosition, 4), 172800) // 48 hours in seconds
        }

        emit DiamondInitialized(owner, entryPoint, treasury);
    }

    /**
     * @notice Minimal initialization (owner only)
     * @param owner The owner address
     */
    function initMinimal(address owner) external {
        LibDiamond.setContractOwner(owner);

        // Initialize account storage with owner
        bytes32 accountPosition = keccak256("cppay.account.storage");
        assembly {
            sstore(accountPosition, owner)
        }
    }
}
