// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/CPPayDiamond.sol";
import "../contracts/CPPayFactory.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ConfigFacet.sol";
import "../contracts/facets/InitDiamond.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/interfaces/IDiamondLoupe.sol";
import "../contracts/interfaces/IERC173.sol";
import "../contracts/mocks/MockEntryPoint.sol";
import "../contracts/mocks/MockCNGN.sol";

contract FactoryAndDiamondTest is Test {
    CPPayFactory factory;
    DiamondCutFacet diamondCut;
    DiamondLoupeFacet diamondLoupe;
    OwnershipFacet ownershipFacet;
    ConfigFacet configFacet;
    InitDiamond initDiamond;
    MockEntryPoint entryPoint;
    MockCNGN cngn;

    address owner = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);
    address treasury = address(0x4);
    address newTreasury = address(0x5);

    event WalletCreated(address indexed user, address indexed diamond, uint256 timestamp);
    event WalletImported(
        address indexed user, address indexed diamond, address indexed importedAddress, uint256 timestamp
    );
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event CNGNUpdated(address indexed oldCNGN, address indexed newCNGN);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public {
        // Deploy mocks
        entryPoint = new MockEntryPoint();
        cngn = new MockCNGN();

        // Deploy facets
        diamondCut = new DiamondCutFacet();
        diamondLoupe = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        configFacet = new ConfigFacet();
        initDiamond = new InitDiamond();

        // Deploy factory
        factory = new CPPayFactory(address(entryPoint), treasury, address(cngn));
    }

    // ============ CPPayFactory Tests ============

    function testFactoryConstructor() public {
        assertEq(factory.owner(), address(this));
        assertEq(factory.entryPoint(), address(entryPoint));
        assertEq(factory.treasury(), treasury);
        assertEq(factory.cngn(), address(cngn));
    }

    function testFactoryCannotDeployWithZeroEntryPoint() public {
        vm.expectRevert(CPPayFactory.InvalidAddress.selector);
        new CPPayFactory(address(0), treasury, address(cngn));
    }

    function testFactoryCannotDeployWithZeroTreasury() public {
        vm.expectRevert(CPPayFactory.InvalidAddress.selector);
        new CPPayFactory(address(entryPoint), address(0), address(cngn));
    }

    function testCreateWallet() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = DiamondLoupeFacet.facets.selector;

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupe),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        vm.expectEmit(false, false, false, false);
        emit WalletCreated(user1, address(0), 0);

        address diamond = factory.createWallet(user1, cuts, "");

        assertTrue(factory.isDeployedWallet(diamond));
        assertEq(factory.walletCount(), 1);
        assertEq(factory.getWallet(0), diamond);
    }

    function testCreateWalletCannotUseZeroAddress() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);

        vm.expectRevert(CPPayFactory.InvalidAddress.selector);
        factory.createWallet(address(0), cuts, "");
    }

    function testCreateImportedWallet() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);

        vm.expectEmit(false, false, true, false);
        emit WalletImported(user1, address(0), user2, 0);

        address diamond = factory.createImportedWallet(user1, user2, 0, cuts, "");

        assertTrue(factory.isDeployedWallet(diamond));
    }

    function testCreateImportedWalletCannotUseZeroUser() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);

        vm.expectRevert(CPPayFactory.InvalidAddress.selector);
        factory.createImportedWallet(address(0), user2, 0, cuts, "");
    }

    function testCreateImportedWalletCannotUseZeroImportedAddress() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);

        vm.expectRevert(CPPayFactory.InvalidAddress.selector);
        factory.createImportedWallet(user1, address(0), 0, cuts, "");
    }

    function testCreateWalletDeterministic() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);
        bytes32 salt = keccak256("test-salt");

        address diamond = factory.createWalletDeterministic(user1, cuts, salt);

        assertTrue(factory.isDeployedWallet(diamond));
        assertEq(factory.walletCount(), 1);
    }

    function testCreateWalletDeterministicCannotUseZeroAddress() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);
        bytes32 salt = keccak256("test-salt");

        vm.expectRevert(CPPayFactory.InvalidAddress.selector);
        factory.createWalletDeterministic(address(0), cuts, salt);
    }

    function testPredictWalletAddress() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);
        bytes32 salt = keccak256("test-salt");

        address predicted = factory.computeAddress(user1, cuts, salt);
        address actual = factory.createWalletDeterministic(user1, cuts, salt);

        assertEq(predicted, actual);
    }

    function testSetTreasury() public {
        vm.expectEmit(true, true, false, false);
        emit TreasuryUpdated(treasury, newTreasury);

        factory.setTreasury(newTreasury);

        assertEq(factory.treasury(), newTreasury);
    }

    function testSetTreasuryCannotUseZeroAddress() public {
        vm.expectRevert(CPPayFactory.InvalidAddress.selector);
        factory.setTreasury(address(0));
    }

    function testSetTreasuryOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert(CPPayFactory.Unauthorized.selector);
        factory.setTreasury(newTreasury);
    }

    function testSetCNGN() public {
        address newCNGN = address(0x999);

        vm.expectEmit(true, true, false, false);
        emit CNGNUpdated(address(cngn), newCNGN);

        factory.setCNGN(newCNGN);

        assertEq(factory.cngn(), newCNGN);
    }

    function testSetCNGNCannotUseZeroAddress() public {
        vm.expectRevert(CPPayFactory.InvalidAddress.selector);
        factory.setCNGN(address(0));
    }

    function testSetCNGNOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert(CPPayFactory.Unauthorized.selector);
        factory.setCNGN(address(0x999));
    }

    function testWalletCount() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);

        assertEq(factory.walletCount(), 0);

        factory.createWallet(user1, cuts, "");
        assertEq(factory.walletCount(), 1);

        factory.createWallet(user2, cuts, "");
        assertEq(factory.walletCount(), 2);
    }

    function testGetWallet() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);

        address diamond1 = factory.createWallet(user1, cuts, "");
        address diamond2 = factory.createWallet(user2, cuts, "");

        assertEq(factory.getWallet(0), diamond1);
        assertEq(factory.getWallet(1), diamond2);
    }

    // ============ Diamond Core Tests ============

    function testDiamondOwnership() public {
        IDiamondCut.FacetCut[] memory cuts = _createOwnershipCuts();

        address diamond = factory.createWallet(owner, cuts, "");

        assertEq(IERC173(diamond).owner(), owner);
    }

    function testDiamondTransferOwnership() public {
        IDiamondCut.FacetCut[] memory cuts = _createOwnershipCuts();
        address diamond = factory.createWallet(owner, cuts, "");

        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, user1);

        IERC173(diamond).transferOwnership(user1);

        assertEq(IERC173(diamond).owner(), user1);
    }

    function testDiamondTransferOwnershipOnlyOwner() public {
        IDiamondCut.FacetCut[] memory cuts = _createOwnershipCuts();
        address diamond = factory.createWallet(owner, cuts, "");

        vm.prank(user1);
        vm.expectRevert();
        IERC173(diamond).transferOwnership(user2);
    }

    // ============ DiamondLoupe Tests ============

    function testDiamondLoupeFacets() public {
        IDiamondCut.FacetCut[] memory cuts = _createLoupeCuts();
        address diamond = factory.createWallet(owner, cuts, "");

        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(diamond).facets();

        assertGt(facets.length, 0);
    }

    function testDiamondLoupeFacetFunctionSelectors() public {
        IDiamondCut.FacetCut[] memory cuts = _createLoupeCuts();
        address diamond = factory.createWallet(owner, cuts, "");

        bytes4[] memory selectors = IDiamondLoupe(diamond).facetFunctionSelectors(address(diamondLoupe));

        assertGt(selectors.length, 0);
    }

    function testDiamondLoupeFacetAddresses() public {
        IDiamondCut.FacetCut[] memory cuts = _createLoupeCuts();
        address diamond = factory.createWallet(owner, cuts, "");

        address[] memory addresses = IDiamondLoupe(diamond).facetAddresses();

        assertGt(addresses.length, 0);
        assertEq(addresses[0], address(diamondLoupe));
    }

    function testDiamondLoupeFacetAddress() public {
        IDiamondCut.FacetCut[] memory cuts = _createLoupeCuts();
        address diamond = factory.createWallet(owner, cuts, "");

        address facetAddr = IDiamondLoupe(diamond).facetAddress(DiamondLoupeFacet.facets.selector);

        assertEq(facetAddr, address(diamondLoupe));
    }

    // ============ DiamondCut Tests ============

    function testDiamondCutAddFacet() public {
        // Create diamond with cut facet
        IDiamondCut.FacetCut[] memory initialCuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory cutSelectors = new bytes4[](1);
        cutSelectors[0] = DiamondCutFacet.diamondCut.selector;

        initialCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondCut),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: cutSelectors
        });

        address diamond = factory.createWallet(owner, initialCuts, "");

        // Add loupe facet
        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;

        addCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupe),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        vm.prank(owner);
        IDiamondCut(diamond).diamondCut(addCuts, address(0), "");

        // Verify facet was added
        address facetAddr = IDiamondLoupe(diamond).facetAddress(DiamondLoupeFacet.facets.selector);
        assertEq(facetAddr, address(diamondLoupe));
    }

    function testDiamondCutOnlyOwner() public {
        IDiamondCut.FacetCut[] memory initialCuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory cutSelectors = new bytes4[](1);
        cutSelectors[0] = DiamondCutFacet.diamondCut.selector;

        initialCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondCut),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: cutSelectors
        });

        address diamond = factory.createWallet(owner, initialCuts, "");

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        vm.expectRevert();
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    // ============ Helper Functions ============

    function _createOwnershipCuts() internal view returns (IDiamondCut.FacetCut[] memory) {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = OwnershipFacet.transferOwnership.selector;
        selectors[1] = OwnershipFacet.owner.selector;

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        return cuts;
    }

    function _createLoupeCuts() internal view returns (IDiamondCut.FacetCut[] memory) {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = DiamondLoupeFacet.facets.selector;
        selectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        selectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        selectors[3] = DiamondLoupeFacet.facetAddress.selector;

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupe),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        return cuts;
    }
}
