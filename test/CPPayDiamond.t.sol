// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/CPPayDiamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/AccountFacet.sol";
import "../contracts/facets/GuardianFacet.sol";
import "../contracts/facets/SessionKeyFacet.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/interfaces/IDiamondLoupe.sol";

contract CPPayDiamondTest is Test {
    CPPayDiamond diamond;
    DiamondCutFacet diamondCutFacet;
    DiamondLoupeFacet diamondLoupeFacet;
    OwnershipFacet ownershipFacet;
    AccountFacet accountFacet;
    GuardianFacet guardianFacet;
    SessionKeyFacet sessionKeyFacet;

    address owner = address(0x1);
    address user = address(0x2);
    address guardian1 = address(0x3);
    address guardian2 = address(0x4);
    address guardian3 = address(0x5);

    function setUp() public {
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        accountFacet = new AccountFacet();
        guardianFacet = new GuardianFacet();
        sessionKeyFacet = new SessionKeyFacet();

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](6);

        bytes4[] memory cutSelectors = new bytes4[](1);
        cutSelectors[0] = DiamondCutFacet.diamondCut.selector;
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondCutFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: cutSelectors
        });

        bytes4[] memory loupeSelectors = new bytes4[](5);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;
        loupeSelectors[4] = DiamondLoupeFacet.supportsInterface.selector;
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        bytes4[] memory ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = OwnershipFacet.transferOwnership.selector;
        ownershipSelectors[1] = OwnershipFacet.owner.selector;
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });

        bytes4[] memory accountSelectors = new bytes4[](7);
        accountSelectors[0] = AccountFacet.initialize.selector;
        accountSelectors[1] = AccountFacet.validateUserOp.selector;
        accountSelectors[2] = AccountFacet.execute.selector;
        accountSelectors[3] = AccountFacet.executeBatch.selector;
        accountSelectors[4] = AccountFacet.setExecutor.selector;
        accountSelectors[5] = AccountFacet.getNonce.selector;
        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(accountFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: accountSelectors
        });

        bytes4[] memory guardianSelectors = new bytes4[](8);
        guardianSelectors[0] = GuardianFacet.addGuardian.selector;
        guardianSelectors[1] = GuardianFacet.removeGuardian.selector;
        guardianSelectors[2] = GuardianFacet.setThreshold.selector;
        guardianSelectors[3] = GuardianFacet.initiateRecovery.selector;
        guardianSelectors[4] = GuardianFacet.executeRecovery.selector;
        guardianSelectors[5] = GuardianFacet.cancelRecovery.selector;
        guardianSelectors[6] = GuardianFacet.getGuardians.selector;
        guardianSelectors[7] = GuardianFacet.getThreshold.selector;
        cut[4] = IDiamondCut.FacetCut({
            facetAddress: address(guardianFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: guardianSelectors
        });

        bytes4[] memory sessionSelectors = new bytes4[](6);
        sessionSelectors[0] = SessionKeyFacet.createSession.selector;
        sessionSelectors[1] = SessionKeyFacet.executeWithSession.selector;
        sessionSelectors[2] = SessionKeyFacet.revokeSession.selector;
        sessionSelectors[3] = SessionKeyFacet.getSession.selector;
        sessionSelectors[4] = SessionKeyFacet.getUserSessions.selector;
        sessionSelectors[5] = SessionKeyFacet.isSessionValid.selector;
        cut[5] = IDiamondCut.FacetCut({
            facetAddress: address(sessionKeyFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: sessionSelectors
        });

        diamond = new CPPayDiamond(cut, owner);
    }

    function testDiamondDeployment() public {
        IDiamondLoupe loupe = IDiamondLoupe(address(diamond));
        address[] memory facetAddresses = loupe.facetAddresses();
        assertEq(facetAddresses.length, 6);
    }

    function testOwnership() public {
        OwnershipFacet ownership = OwnershipFacet(address(diamond));
        assertEq(ownership.owner(), owner);
    }

    function testAccountInitialization() public {
        AccountFacet account = AccountFacet(address(diamond));
        address entryPoint = address(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);
        
        vm.prank(owner);
        account.initialize(user, entryPoint);
        
        assertEq(account.owner(), user);
    }

    function testGuardianManagement() public {
        AccountFacet account = AccountFacet(address(diamond));
        GuardianFacet guardian = GuardianFacet(address(diamond));
        
        vm.prank(owner);
        account.initialize(user, address(0));
        
        vm.startPrank(user);
        guardian.addGuardian(guardian1);
        guardian.addGuardian(guardian2);
        guardian.addGuardian(guardian3);
        guardian.setThreshold(2);
        vm.stopPrank();
        
        address[] memory guardians = guardian.getGuardians();
        assertEq(guardians.length, 3);
        assertEq(guardian.getThreshold(), 2);
    }

    function testSessionKeyCreation() public {
        AccountFacet account = AccountFacet(address(diamond));
        SessionKeyFacet session = SessionKeyFacet(address(diamond));
        
        vm.prank(owner);
        account.initialize(user, address(0));
        
        bytes4[] memory allowedFunctions = new bytes4[](1);
        allowedFunctions[0] = AccountFacet.execute.selector;
        
        address sessionKey = address(0x999);
        
        vm.prank(user);
        session.createSession(sessionKey, 1 days, 1 ether, allowedFunctions);
        
        assertTrue(session.isSessionValid(sessionKey));
    }

    function testExecuteBatch() public {
        AccountFacet account = AccountFacet(address(diamond));
        
        vm.prank(owner);
        account.initialize(user, address(0));
        
        address[] memory dest = new address[](2);
        dest[0] = address(0x100);
        dest[1] = address(0x200);
        
        uint256[] memory values = new uint256[](2);
        values[0] = 0.1 ether;
        values[1] = 0.2 ether;
        
        bytes[] memory funcs = new bytes[](2);
        funcs[0] = "";
        funcs[1] = "";
        
        vm.deal(address(diamond), 1 ether);
        
        vm.prank(user);
        account.executeBatch(dest, values, funcs);
        
        assertEq(address(0x100).balance, 0.1 ether);
        assertEq(address(0x200).balance, 0.2 ether);
    }
}
