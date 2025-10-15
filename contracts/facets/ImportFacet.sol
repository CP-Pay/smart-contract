// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";

/**
 * @title ImportFacet
 * @notice Links imported EOA/Smart Wallets to CPPay Diamond accounts
 * @dev Used when users import existing wallets via seed phrase or private key
 */
contract ImportFacet {
    event WalletImported(address indexed diamond, address indexed importedAddress, uint8 walletType, uint256 timestamp);

    event ImportedAddressLinked(address indexed diamond, address indexed importedAddress, bool isAuthorized);

    error ImportFacet__InvalidAddress();
    error ImportFacet__AlreadyLinked();

    /**
     * @notice Links an imported wallet address to this Diamond
     * @param importedAddress The address from imported seed phrase/key
     * @param walletType 0=EOA, 1=SmartWallet, 2=Hardware
     */
    function linkImportedAddress(address importedAddress, uint8 walletType) external {
        LibDiamond.enforceIsContractOwner();

        if (importedAddress == address(0)) {
            revert ImportFacet__InvalidAddress();
        }

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();

        if (s.importedAddresses[address(this)] != address(0)) {
            revert ImportFacet__AlreadyLinked();
        }

        s.importedAddresses[address(this)] = importedAddress;
        s.isImportedWallet[address(this)] = true;

        emit WalletImported(address(this), importedAddress, walletType, block.timestamp);

        emit ImportedAddressLinked(address(this), importedAddress, true);
    }

    /**
     * @notice Get import information for this Diamond
     * @return isImported True if wallet was created via import
     * @return importedAddress The original imported address (zero if not imported)
     */
    function getImportInfo() external view returns (bool isImported, address importedAddress) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();

        isImported = s.isImportedWallet[address(this)];
        importedAddress = s.importedAddresses[address(this)];
    }

    /**
     * @notice Check if address can sign transactions for this Diamond
     * @param signer Address to verify
     * @return True if signer is owner or imported address
     */
    function isAuthorizedSigner(address signer) external view returns (bool) {
        // Owner is always authorized
        if (signer == LibDiamond.contractOwner()) {
            return true;
        }

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();

        // Imported address is authorized if linked
        if (s.isImportedWallet[address(this)]) {
            return signer == s.importedAddresses[address(this)];
        }

        return false;
    }

    /**
     * @notice Unlink imported address (e.g. if compromised)
     * @dev Only owner can unlink for security
     */
    function unlinkImportedAddress() external {
        LibDiamond.enforceIsContractOwner();

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();

        address oldImported = s.importedAddresses[address(this)];

        delete s.importedAddresses[address(this)];
        s.isImportedWallet[address(this)] = false;

        emit ImportedAddressLinked(address(this), oldImported, false);
    }
}
