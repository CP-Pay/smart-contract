// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CPPayDiamond.sol";
import "./interfaces/IDiamondCut.sol";
import "./libraries/LibDiamond.sol";
import "./facets/ImportFacet.sol";

/**
 * @title CPPayFactory
 * @notice Factory contract for deploying CPPay Diamond proxies
 * @dev Each user gets their own Diamond smart account
 */
contract CPPayFactory {
    address public immutable owner;
    address public immutable entryPoint;
    address public treasury;
    address public cngn;

    // Default facet addresses
    address[] public defaultFacets;
    mapping(address => bool) public isDeployedWallet;
    address[] public allWallets;

    event WalletCreated(address indexed user, address indexed diamond, uint256 timestamp);
    event WalletImported(
        address indexed user, address indexed diamond, address indexed importedAddress, uint256 timestamp
    );
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event CNGNUpdated(address indexed oldCNGN, address indexed newCNGN);
    event FacetAdded(address indexed facet);

    error Unauthorized();
    error InvalidAddress();
    error DeploymentFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor(address _entryPoint, address _treasury, address _cngn) {
        if (_entryPoint == address(0) || _treasury == address(0)) {
            revert InvalidAddress();
        }

        owner = msg.sender;
        entryPoint = _entryPoint;
        treasury = _treasury;
        cngn = _cngn;
    }

    /**
     * @notice Deploy a new Diamond smart account for a user
     * @param user The owner of the new wallet
     * @param facetCuts The facets to initialize the Diamond with
     * @param initData Optional initialization data
     * @return diamond The address of the deployed Diamond
     */
    function createWallet(address user, IDiamondCut.FacetCut[] memory facetCuts, bytes memory initData)
        external
        returns (address diamond)
    {
        if (user == address(0)) revert InvalidAddress();

        // Deploy Diamond with user as owner
        try new CPPayDiamond(facetCuts, user) returns (CPPayDiamond newDiamond) {
            diamond = address(newDiamond);
        } catch {
            revert DeploymentFailed();
        }

        // Initialize if needed
        if (initData.length > 0) {
            (bool success,) = diamond.call(initData);
            if (!success) revert DeploymentFailed();
        }

        // Track wallet
        isDeployedWallet[diamond] = true;
        allWallets.push(diamond);

        emit WalletCreated(user, diamond, block.timestamp);
    }

    /**
     * @notice Deploy Diamond for imported wallet (from seed phrase/private key)
     * @param user The owner of the Diamond
     * @param importedAddress The address derived from imported seed/key
     * @param walletType 0=EOA, 1=SmartWallet, 2=Hardware
     * @param facetCuts The facets to initialize
     * @param initData Optional initialization data
     * @return diamond The address of the deployed Diamond
     */
    function createImportedWallet(
        address user,
        address importedAddress,
        uint8 walletType,
        IDiamondCut.FacetCut[] memory facetCuts,
        bytes memory initData
    ) external returns (address diamond) {
        if (user == address(0) || importedAddress == address(0)) {
            revert InvalidAddress();
        }

        // Deploy Diamond with user as owner
        try new CPPayDiamond(facetCuts, user) returns (CPPayDiamond newDiamond) {
            diamond = address(newDiamond);
        } catch {
            revert DeploymentFailed();
        }

        // Initialize if needed
        if (initData.length > 0) {
            (bool success,) = diamond.call(initData);
            if (!success) revert DeploymentFailed();
        }

        // Note: The owner must call ImportFacet.linkImportedAddress() after creation
        // Factory cannot call it because only the owner can link imported addresses

        // Track wallet
        isDeployedWallet[diamond] = true;
        allWallets.push(diamond);

        emit WalletImported(user, diamond, importedAddress, block.timestamp);
    }

    /**
     * @notice Deploy wallet with deterministic address (CREATE2)
     * @param user The owner of the new wallet
     * @param facetCuts The facets to initialize
     * @param salt The salt for CREATE2
     * @return diamond The address of the deployed Diamond
     */
    function createWalletDeterministic(address user, IDiamondCut.FacetCut[] memory facetCuts, bytes32 salt)
        external
        returns (address diamond)
    {
        if (user == address(0)) revert InvalidAddress();

        bytes memory bytecode = abi.encodePacked(type(CPPayDiamond).creationCode, abi.encode(facetCuts, user));

        assembly {
            diamond := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(diamond) { revert(0, 0) }
        }

        // Track wallet
        isDeployedWallet[diamond] = true;
        allWallets.push(diamond);

        emit WalletCreated(user, diamond, block.timestamp);
    }

    /**
     * @notice Compute deterministic address before deployment
     * @param user The owner
     * @param facetCuts The facets
     * @param salt The salt
     * @return predicted The predicted address
     */
    function computeAddress(address user, IDiamondCut.FacetCut[] memory facetCuts, bytes32 salt)
        external
        view
        returns (address predicted)
    {
        bytes memory bytecode = abi.encodePacked(type(CPPayDiamond).creationCode, abi.encode(facetCuts, user));

        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));

        predicted = address(uint160(uint256(hash)));
    }

    /**
     * @notice Set treasury address
     * @param newTreasury The new treasury address
     */
    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert InvalidAddress();
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    /**
     * @notice Set CNGN token address
     * @param newCNGN The new CNGN address
     */
    function setCNGN(address newCNGN) external onlyOwner {
        if (newCNGN == address(0)) revert InvalidAddress();
        address oldCNGN = cngn;
        cngn = newCNGN;
        emit CNGNUpdated(oldCNGN, newCNGN);
    }

    /**
     * @notice Get total number of deployed wallets
     * @return count The total count
     */
    function walletCount() external view returns (uint256 count) {
        return allWallets.length;
    }

    /**
     * @notice Get wallet at index
     * @param index The index
     * @return wallet The wallet address
     */
    function getWallet(uint256 index) external view returns (address wallet) {
        require(index < allWallets.length, "Index out of bounds");
        return allWallets[index];
    }
}
