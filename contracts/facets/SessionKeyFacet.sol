// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibAppStorage.sol";
import "../libraries/LibDiamond.sol";

contract SessionKeyFacet {
    error InvalidDuration();
    error InvalidAmount();
    error NoFunctions();
    error AlreadyExists();
    error NotFound();
    error SessionRevoked();
    error SessionExpired();
    error LimitExceeded();
    error FunctionNotAllowed();
    error UnauthorizedKey();

    function createSessionKey(address key, uint256 duration, uint256 maxAmount, bytes4[] calldata allowedFunctions)
        external
        returns (bytes32 keyId)
    {
        if (key == address(0)) revert NotFound();
        if (duration == 0 || duration > 7 days) revert InvalidDuration();
        if (maxAmount == 0) revert InvalidAmount();
        if (allowedFunctions.length == 0) revert NoFunctions();

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        keyId = keccak256(abi.encodePacked(msg.sender, key, block.timestamp));

        if (s.sessionKeys[keyId].key != address(0)) {
            revert AlreadyExists();
        }

        uint256 expiry = block.timestamp + duration;

        s.sessionKeys[keyId] = LibAppStorage.SessionKey({
            key: key,
            expiry: expiry,
            selectors: allowedFunctions,
            perTxGasCap: maxAmount,
            spentAmount: 0,
            revoked: false
        });

        s.userSessionKeys[msg.sender].push(keyId);
        emit LibAppStorage.SessionKeyCreated(msg.sender, keyId, expiry);
    }

    function revokeSessionKey(bytes32 keyId) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        LibAppStorage.SessionKey storage sessionKey = s.sessionKeys[keyId];

        if (sessionKey.key == address(0)) revert NotFound();
        sessionKey.revoked = true;
        emit LibAppStorage.SessionKeyRevoked(msg.sender, keyId);
    }

    function isValidSessionKey(bytes32 keyId, bytes4 selector, uint256 gasLimit) external view returns (bool isValid) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        LibAppStorage.SessionKey storage sessionKey = s.sessionKeys[keyId];

        if (sessionKey.key == address(0)) return false;
        if (sessionKey.revoked) return false;
        if (block.timestamp > sessionKey.expiry) return false;
        if (gasLimit > sessionKey.perTxGasCap) return false;

        bool selectorAllowed = false;
        for (uint256 i = 0; i < sessionKey.selectors.length; i++) {
            if (sessionKey.selectors[i] == selector) {
                selectorAllowed = true;
                break;
            }
        }

        return selectorAllowed;
    }

    function executeWithSession(bytes32 keyId, address dest, uint256 value, bytes calldata data) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        LibAppStorage.SessionKey storage sessionKey = s.sessionKeys[keyId];

        if (sessionKey.key == address(0)) revert NotFound();
        if (msg.sender != sessionKey.key) revert UnauthorizedKey();
        if (sessionKey.revoked) revert SessionRevoked();
        if (block.timestamp > sessionKey.expiry) revert SessionExpired();
        if (sessionKey.spentAmount + value > sessionKey.perTxGasCap) revert LimitExceeded();

        bytes4 functionSelector = bytes4(data[:4]);
        bool functionAllowed = false;
        for (uint256 i = 0; i < sessionKey.selectors.length; i++) {
            if (sessionKey.selectors[i] == functionSelector) {
                functionAllowed = true;
                break;
            }
        }
        if (!functionAllowed) revert FunctionNotAllowed();

        sessionKey.spentAmount += value;

        (bool success, bytes memory result) = dest.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function getSessionKey(bytes32 keyId)
        external
        view
        returns (address key, uint256 expiry, uint256 perTxGasCap, uint256 spentAmount, bool revoked)
    {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        LibAppStorage.SessionKey storage sessionKey = s.sessionKeys[keyId];
        return (sessionKey.key, sessionKey.expiry, sessionKey.perTxGasCap, sessionKey.spentAmount, sessionKey.revoked);
    }

    function getUserSessionKeys(address user) external view returns (bytes32[] memory keyIds) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        return s.userSessionKeys[user];
    }
}
