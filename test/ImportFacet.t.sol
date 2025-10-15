// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/CPPayDiamond.sol";
import "../contracts/CPPayFactory.sol";
import "../contracts/facets/ImportFacet.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/AccountFacet.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/mocks/MockEntryPoint.sol";
import "../contracts/mocks/MockCNGN.sol";

contract ImportFacetTest is Test {
    CPPayFactory factory;
    ImportFacet importFacet;
    DiamondCutFacet diamondCut;
    AccountFacet accountFacet;
    MockEntryPoint entryPoint;
    MockCNGN cngn;

    address owner = address(0x1);
    address importedEOA = address(0x2);
    address treasury = address(0x3);

    function setUp() public {
        // Deploy mocks
        entryPoint = new MockEntryPoint();
        cngn = new MockCNGN();

        // Deploy facets
        diamondCut = new DiamondCutFacet();
        importFacet = new ImportFacet();
        accountFacet = new AccountFacet();

        // Deploy factory
        factory = new CPPayFactory(address(entryPoint), treasury, address(cngn));
    }

    function testLinkImportedAddress() public {
        // Create Diamond wallet
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = ImportFacet.linkImportedAddress.selector;
        selectors[1] = ImportFacet.getImportInfo.selector;
        selectors[2] = ImportFacet.isAuthorizedSigner.selector;
        selectors[3] = ImportFacet.unlinkImportedAddress.selector;

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(importFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        address diamond = factory.createWallet(owner, cuts, "");

        // Link imported address
        vm.prank(owner);
        ImportFacet(diamond).linkImportedAddress(importedEOA, 0); // 0 = EOA

        // Verify import info
        (bool isImported, address linked) = ImportFacet(diamond).getImportInfo();
        assertTrue(isImported);
        assertEq(linked, importedEOA);
    }

    function testIsAuthorizedSigner() public {
        // Create and link wallet
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = ImportFacet.linkImportedAddress.selector;
        selectors[1] = ImportFacet.getImportInfo.selector;
        selectors[2] = ImportFacet.isAuthorizedSigner.selector;
        selectors[3] = ImportFacet.unlinkImportedAddress.selector;

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(importFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        address diamond = factory.createWallet(owner, cuts, "");

        vm.prank(owner);
        ImportFacet(diamond).linkImportedAddress(importedEOA, 0);

        // Owner should be authorized
        assertTrue(ImportFacet(diamond).isAuthorizedSigner(owner));

        // Imported address should be authorized
        assertTrue(ImportFacet(diamond).isAuthorizedSigner(importedEOA));

        // Random address should NOT be authorized
        assertFalse(ImportFacet(diamond).isAuthorizedSigner(address(0x999)));
    }

    function testUnlinkImportedAddress() public {
        // Create and link wallet
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = ImportFacet.linkImportedAddress.selector;
        selectors[1] = ImportFacet.getImportInfo.selector;
        selectors[2] = ImportFacet.isAuthorizedSigner.selector;
        selectors[3] = ImportFacet.unlinkImportedAddress.selector;

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(importFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        address diamond = factory.createWallet(owner, cuts, "");

        vm.prank(owner);
        ImportFacet(diamond).linkImportedAddress(importedEOA, 0);

        // Verify linked
        (bool isImported, address linked) = ImportFacet(diamond).getImportInfo();
        assertTrue(isImported);

        // Unlink
        vm.prank(owner);
        ImportFacet(diamond).unlinkImportedAddress();

        // Verify unlinked
        (isImported, linked) = ImportFacet(diamond).getImportInfo();
        assertFalse(isImported);
        assertEq(linked, address(0));

        // Imported address no longer authorized
        assertFalse(ImportFacet(diamond).isAuthorizedSigner(importedEOA));
    }

    function testCannotLinkZeroAddress() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = ImportFacet.linkImportedAddress.selector;
        selectors[1] = ImportFacet.getImportInfo.selector;
        selectors[2] = ImportFacet.isAuthorizedSigner.selector;
        selectors[3] = ImportFacet.unlinkImportedAddress.selector;

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(importFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        address diamond = factory.createWallet(owner, cuts, "");

        vm.prank(owner);
        vm.expectRevert(ImportFacet.ImportFacet__InvalidAddress.selector);
        ImportFacet(diamond).linkImportedAddress(address(0), 0);
    }

    function testOnlyOwnerCanLink() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = ImportFacet.linkImportedAddress.selector;
        selectors[1] = ImportFacet.getImportInfo.selector;
        selectors[2] = ImportFacet.isAuthorizedSigner.selector;
        selectors[3] = ImportFacet.unlinkImportedAddress.selector;

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(importFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        address diamond = factory.createWallet(owner, cuts, "");

        // Non-owner tries to link
        vm.prank(address(0x999));
        vm.expectRevert(); // LibDiamond reverts with custom error
        ImportFacet(diamond).linkImportedAddress(importedEOA, 0);
    }

    function testCannotLinkTwice() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = ImportFacet.linkImportedAddress.selector;
        selectors[1] = ImportFacet.getImportInfo.selector;
        selectors[2] = ImportFacet.isAuthorizedSigner.selector;
        selectors[3] = ImportFacet.unlinkImportedAddress.selector;

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(importFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        address diamond = factory.createWallet(owner, cuts, "");

        vm.startPrank(owner);
        ImportFacet(diamond).linkImportedAddress(importedEOA, 0);

        // Try linking again
        vm.expectRevert(ImportFacet.ImportFacet__AlreadyLinked.selector);
        ImportFacet(diamond).linkImportedAddress(address(0x4), 0);
        vm.stopPrank();
    }

    function testFactoryCreateImportedWallet() public {
        // Create basic cuts without ImportFacet
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = ImportFacet.linkImportedAddress.selector;
        selectors[1] = ImportFacet.getImportInfo.selector;
        selectors[2] = ImportFacet.isAuthorizedSigner.selector;
        selectors[3] = ImportFacet.unlinkImportedAddress.selector;

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(importFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        // Use factory's createImportedWallet
        address diamond = factory.createImportedWallet(
            owner,
            importedEOA,
            0, // EOA
            cuts,
            ""
        );

        // Owner must link the imported address after creation
        vm.prank(owner);
        ImportFacet(diamond).linkImportedAddress(importedEOA, 0);

        // Verify import info
        (bool isImported, address linked) = ImportFacet(diamond).getImportInfo();
        assertTrue(isImported);
        assertEq(linked, importedEOA);
    }
}
