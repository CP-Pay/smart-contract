// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibAppStorage.sol";
import "../libraries/LibDiamond.sol";

/**
 * @title ConfigFacet
 * @notice Manages system configuration and supported tokens
 */
contract ConfigFacet {
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event EntryPointUpdated(address indexed oldEntryPoint, address indexed newEntryPoint);
    event CNGNUpdated(address indexed oldCNGN, address indexed newCNGN);
    event TokenSupported(address indexed token, bool supported);

    error InvalidAddress();

    /**
     * @notice Initialize the application storage
     * @param treasury The treasury address
     * @param entryPoint The ERC-4337 EntryPoint address
     * @param cngn The CNGN token address
     */
    function initializeApp(address treasury, address entryPoint, address cngn) external {
        LibDiamond.enforceIsContractOwner();

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();

        if (s.treasury != address(0)) {
            revert("Already initialized");
        }

        if (treasury == address(0) || entryPoint == address(0)) {
            revert InvalidAddress();
        }

        s.treasury = treasury;
        s.entryPoint = entryPoint;
        s.cngn = cngn;
    }

    /**
     * @notice Set treasury address
     * @param newTreasury The new treasury address
     */
    function setTreasury(address newTreasury) external {
        LibDiamond.enforceIsContractOwner();

        if (newTreasury == address(0)) revert InvalidAddress();

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        address oldTreasury = s.treasury;
        s.treasury = newTreasury;

        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    /**
     * @notice Set EntryPoint address
     * @param newEntryPoint The new EntryPoint address
     */
    function setEntryPoint(address newEntryPoint) external {
        LibDiamond.enforceIsContractOwner();

        if (newEntryPoint == address(0)) revert InvalidAddress();

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        address oldEntryPoint = s.entryPoint;
        s.entryPoint = newEntryPoint;

        emit EntryPointUpdated(oldEntryPoint, newEntryPoint);
    }

    /**
     * @notice Set CNGN token address
     * @param newCNGN The new CNGN address
     */
    function setCNGN(address newCNGN) external {
        LibDiamond.enforceIsContractOwner();

        if (newCNGN == address(0)) revert InvalidAddress();

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        address oldCNGN = s.cngn;
        s.cngn = newCNGN;

        emit CNGNUpdated(oldCNGN, newCNGN);
    }

    /**
     * @notice Add or remove supported token
     * @param token The token address
     * @param supported Whether the token is supported
     */
    function setSupportedToken(address token, bool supported) external {
        LibDiamond.enforceIsContractOwner();

        if (token == address(0)) revert InvalidAddress();

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();

        bool currentlySupported = s.isSupportedToken[token];

        if (supported && !currentlySupported) {
            // Add token
            s.supportedTokens.push(token);
            s.isSupportedToken[token] = true;
        } else if (!supported && currentlySupported) {
            // Remove token
            for (uint256 i = 0; i < s.supportedTokens.length; i++) {
                if (s.supportedTokens[i] == token) {
                    s.supportedTokens[i] = s.supportedTokens[s.supportedTokens.length - 1];
                    s.supportedTokens.pop();
                    break;
                }
            }
            s.isSupportedToken[token] = false;
        }

        emit TokenSupported(token, supported);
    }

    /**
     * @notice Get treasury address
     * @return treasury The treasury address
     */
    function getTreasury() external view returns (address treasury) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        return s.treasury;
    }

    /**
     * @notice Get EntryPoint address
     * @return entryPoint The EntryPoint address
     */
    function getEntryPoint() external view returns (address entryPoint) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        return s.entryPoint;
    }

    /**
     * @notice Get CNGN token address
     * @return cngn The CNGN address
     */
    function getCNGN() external view returns (address cngn) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        return s.cngn;
    }

    /**
     * @notice Get all supported tokens
     * @return tokens Array of supported token addresses
     */
    function getSupportedTokens() external view returns (address[] memory tokens) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        return s.supportedTokens;
    }

    /**
     * @notice Check if token is supported
     * @param token The token address
     * @return supported True if token is supported
     */
    function isSupportedToken(address token) external view returns (bool supported) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        return s.isSupportedToken[token];
    }
}
