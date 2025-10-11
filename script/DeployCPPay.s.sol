// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/CPPayDiamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/AccountFacet.sol";
import "../contracts/facets/GuardianFacet.sol";
import "../contracts/facets/SessionKeyFacet.sol";
import "../contracts/facets/PaymasterFacet.sol";
import "../contracts/facets/UtilityFacet.sol";
import "../contracts/interfaces/IDiamondCut.sol";

contract DeployCPPay is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        AccountFacet accountFacet = new AccountFacet();
        GuardianFacet guardianFacet = new GuardianFacet();
        SessionKeyFacet sessionKeyFacet = new SessionKeyFacet();
        PaymasterFacet paymasterFacet = new PaymasterFacet();
        UtilityFacet utilityFacet = new UtilityFacet();

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](8);

        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondCutFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondCutFacet")
        });

        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondLoupeFacet")
        });

        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("OwnershipFacet")
        });

        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(accountFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("AccountFacet")
        });

        cut[4] = IDiamondCut.FacetCut({
            facetAddress: address(guardianFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("GuardianFacet")
        });

        cut[5] = IDiamondCut.FacetCut({
            facetAddress: address(sessionKeyFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("SessionKeyFacet")
        });

        cut[6] = IDiamondCut.FacetCut({
            facetAddress: address(paymasterFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("PaymasterFacet")
        });

        cut[7] = IDiamondCut.FacetCut({
            facetAddress: address(utilityFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("UtilityFacet")
        });

        CPPayDiamond diamond = new CPPayDiamond(cut, deployer);

        console.log("CPPayDiamond deployed at:", address(diamond));
        console.log("DiamondCutFacet deployed at:", address(diamondCutFacet));
        console.log("DiamondLoupeFacet deployed at:", address(diamondLoupeFacet));
        console.log("OwnershipFacet deployed at:", address(ownershipFacet));
        console.log("AccountFacet deployed at:", address(accountFacet));
        console.log("GuardianFacet deployed at:", address(guardianFacet));
        console.log("SessionKeyFacet deployed at:", address(sessionKeyFacet));
        console.log("PaymasterFacet deployed at:", address(paymasterFacet));
        console.log("UtilityFacet deployed at:", address(utilityFacet));

        vm.stopBroadcast();
    }

    function generateSelectors(string memory _facetName) internal pure returns (bytes4[] memory selectors) {
        if (compareStrings(_facetName, "DiamondCutFacet")) {
            selectors = new bytes4[](1);
            selectors[0] = DiamondCutFacet.diamondCut.selector;
        } else if (compareStrings(_facetName, "DiamondLoupeFacet")) {
            selectors = new bytes4[](5);
            selectors[0] = DiamondLoupeFacet.facets.selector;
            selectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
            selectors[2] = DiamondLoupeFacet.facetAddresses.selector;
            selectors[3] = DiamondLoupeFacet.facetAddress.selector;
            selectors[4] = DiamondLoupeFacet.supportsInterface.selector;
        } else if (compareStrings(_facetName, "OwnershipFacet")) {
            selectors = new bytes4[](2);
            selectors[0] = OwnershipFacet.transferOwnership.selector;
            selectors[1] = OwnershipFacet.owner.selector;
        } else if (compareStrings(_facetName, "AccountFacet")) {
            selectors = new bytes4[](7);
            selectors[0] = AccountFacet.initialize.selector;
            selectors[1] = AccountFacet.validateUserOp.selector;
            selectors[2] = AccountFacet.execute.selector;
            selectors[3] = AccountFacet.executeBatch.selector;
            selectors[4] = AccountFacet.setExecutor.selector;
            selectors[5] = AccountFacet.owner.selector;
            selectors[6] = AccountFacet.getNonce.selector;
        } else if (compareStrings(_facetName, "GuardianFacet")) {
            selectors = new bytes4[](8);
            selectors[0] = GuardianFacet.addGuardian.selector;
            selectors[1] = GuardianFacet.removeGuardian.selector;
            selectors[2] = GuardianFacet.setThreshold.selector;
            selectors[3] = GuardianFacet.initiateRecovery.selector;
            selectors[4] = GuardianFacet.executeRecovery.selector;
            selectors[5] = GuardianFacet.cancelRecovery.selector;
            selectors[6] = GuardianFacet.getGuardians.selector;
            selectors[7] = GuardianFacet.getThreshold.selector;
        } else if (compareStrings(_facetName, "SessionKeyFacet")) {
            selectors = new bytes4[](6);
            selectors[0] = SessionKeyFacet.createSession.selector;
            selectors[1] = SessionKeyFacet.executeWithSession.selector;
            selectors[2] = SessionKeyFacet.revokeSession.selector;
            selectors[3] = SessionKeyFacet.getSession.selector;
            selectors[4] = SessionKeyFacet.getUserSessions.selector;
            selectors[5] = SessionKeyFacet.isSessionValid.selector;
        } else if (compareStrings(_facetName, "PaymasterFacet")) {
            selectors = new bytes4[](9);
            selectors[0] = PaymasterFacet.initializePaymaster.selector;
            selectors[1] = PaymasterFacet.validatePaymasterUserOp.selector;
            selectors[2] = PaymasterFacet.postOp.selector;
            selectors[3] = PaymasterFacet.setUserTier.selector;
            selectors[4] = PaymasterFacet.setAcceptedToken.selector;
            selectors[5] = PaymasterFacet.deposit.selector;
            selectors[6] = PaymasterFacet.withdraw.selector;
            selectors[7] = PaymasterFacet.getUserTier.selector;
            selectors[8] = PaymasterFacet.getBalance.selector;
        } else if (compareStrings(_facetName, "UtilityFacet")) {
            selectors = new bytes4[](10);
            selectors[0] = UtilityFacet.pause.selector;
            selectors[1] = UtilityFacet.unpause.selector;
            selectors[2] = UtilityFacet.addAdmin.selector;
            selectors[3] = UtilityFacet.removeAdmin.selector;
            selectors[4] = UtilityFacet.blacklistUser.selector;
            selectors[5] = UtilityFacet.whitelistUser.selector;
            selectors[6] = UtilityFacet.requestEmergencyWithdrawal.selector;
            selectors[7] = UtilityFacet.executeEmergencyWithdrawal.selector;
            selectors[8] = UtilityFacet.isPaused.selector;
            selectors[9] = UtilityFacet.isAdmin.selector;
        }
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
}
