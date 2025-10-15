// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/CPPayDiamond.sol";
import "../contracts/CPPayFactory.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/AccountFacet.sol";
import "../contracts/facets/GuardianFacet.sol";
import "../contracts/facets/SessionKeyFacet.sol";
import "../contracts/facets/PaymasterFacet.sol";
import "../contracts/facets/SwapFacet.sol";
import "../contracts/facets/EscrowFacet.sol";
import "../contracts/facets/SwapEscrowFacet.sol";
import "../contracts/facets/SubscriptionFacet.sol";
import "../contracts/facets/ConfigFacet.sol";
import "../contracts/facets/ImportFacet.sol";
import "../contracts/facets/InitDiamond.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/mocks/MockCNGN.sol";
import "../contracts/mocks/MockEntryPoint.sol";

/**
 * @title DeployCPPayComplete
 * @notice Complete deployment script for CPPay Diamond system
 */
contract DeployCPPayComplete is Script {
    // Facet addresses
    address diamondCutFacet;
    address diamondLoupeFacet;
    address ownershipFacet;
    address accountFacet;
    address guardianFacet;
    address sessionKeyFacet;
    address paymasterFacet;
    address swapFacet;
    address escrowFacet;
    address swapEscrowFacet;
    address subscriptionFacet;
    address configFacet;
    address importFacet;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== CPPay Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy mock contracts
        MockEntryPoint entryPoint = new MockEntryPoint();
        MockCNGN cngn = new MockCNGN();

        console.log("\n=== Mock Contracts ===");
        console.log("EntryPoint:", address(entryPoint));
        console.log("CNGN:", address(cngn));

        // 2. Deploy all facets
        deployFacets();

        console.log("\n=== Facets Deployed ===");
        console.log("DiamondCutFacet:", diamondCutFacet);
        console.log("AccountFacet:", accountFacet);
        console.log("SwapFacet:", swapFacet);
        console.log("EscrowFacet:", escrowFacet);

        // 3. Deploy Factory
        CPPayFactory factory = new CPPayFactory(
            address(entryPoint),
            deployer, // treasury
            address(cngn)
        );

        console.log("\n=== Factory ===");
        console.log("Factory:", address(factory));

        // 4. Create a test Diamond wallet
        IDiamondCut.FacetCut[] memory cuts = prepareFacetCuts();

        address testWallet = factory.createWallet(deployer, cuts, "");

        console.log("\n=== Test Wallet Created ===");
        console.log("Wallet:", testWallet);

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
    }

    function deployFacets() internal {
        diamondCutFacet = address(new DiamondCutFacet());
        diamondLoupeFacet = address(new DiamondLoupeFacet());
        ownershipFacet = address(new OwnershipFacet());
        accountFacet = address(new AccountFacet());
        guardianFacet = address(new GuardianFacet());
        sessionKeyFacet = address(new SessionKeyFacet());
        paymasterFacet = address(new PaymasterFacet());
        swapFacet = address(new SwapFacet());
        escrowFacet = address(new EscrowFacet());
        swapEscrowFacet = address(new SwapEscrowFacet());
        subscriptionFacet = address(new SubscriptionFacet());
        configFacet = address(new ConfigFacet());
        importFacet = address(new ImportFacet());
    }

    function prepareFacetCuts() internal view returns (IDiamondCut.FacetCut[] memory) {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](13);

        // DiamondCutFacet
        bytes4[] memory cutSelectors = new bytes4[](1);
        cutSelectors[0] = DiamondCutFacet.diamondCut.selector;
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: diamondCutFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: cutSelectors
        });

        // DiamondLoupeFacet
        bytes4[] memory loupeSelectors = new bytes4[](5);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;
        loupeSelectors[4] = DiamondLoupeFacet.supportsInterface.selector;
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: diamondLoupeFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        // OwnershipFacet
        bytes4[] memory ownerSelectors = new bytes4[](2);
        ownerSelectors[0] = OwnershipFacet.transferOwnership.selector;
        ownerSelectors[1] = OwnershipFacet.owner.selector;
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: ownershipFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownerSelectors
        });

        // AccountFacet
        bytes4[] memory accountSelectors = new bytes4[](10);
        accountSelectors[0] = AccountFacet.initialize.selector;
        accountSelectors[1] = AccountFacet.validateUserOp.selector;
        accountSelectors[2] = AccountFacet.execute.selector;
        accountSelectors[3] = AccountFacet.executeBatch.selector;
        accountSelectors[4] = AccountFacet.executeBatchAtomic.selector;
        accountSelectors[5] = AccountFacet.executeBatchSequential.selector;
        accountSelectors[6] = AccountFacet.setExecutor.selector;
        accountSelectors[7] = AccountFacet.accountOwner.selector;
        accountSelectors[8] = AccountFacet.getNonce.selector;
        accountSelectors[9] = AccountFacet.isExecutor.selector;
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: accountFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: accountSelectors
        });

        // GuardianFacet
        bytes4[] memory guardianSelectors = new bytes4[](8);
        guardianSelectors[0] = GuardianFacet.addGuardian.selector;
        guardianSelectors[1] = GuardianFacet.removeGuardian.selector;
        guardianSelectors[2] = GuardianFacet.setThreshold.selector;
        guardianSelectors[3] = GuardianFacet.initiateRecovery.selector;
        guardianSelectors[4] = GuardianFacet.voteRecovery.selector;
        guardianSelectors[5] = GuardianFacet.executeRecovery.selector;
        guardianSelectors[6] = GuardianFacet.cancelRecovery.selector;
        guardianSelectors[7] = GuardianFacet.getGuardians.selector;
        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: guardianFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: guardianSelectors
        });

        // SessionKeyFacet
        bytes4[] memory sessionSelectors = new bytes4[](6);
        sessionSelectors[0] = SessionKeyFacet.createSessionKey.selector;
        sessionSelectors[1] = SessionKeyFacet.revokeSessionKey.selector;
        sessionSelectors[2] = SessionKeyFacet.isValidSessionKey.selector;
        sessionSelectors[3] = SessionKeyFacet.executeWithSession.selector;
        sessionSelectors[4] = SessionKeyFacet.getSessionKey.selector;
        sessionSelectors[5] = SessionKeyFacet.getUserSessionKeys.selector;
        cuts[5] = IDiamondCut.FacetCut({
            facetAddress: sessionKeyFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: sessionSelectors
        });

        // PaymasterFacet
        bytes4[] memory paymasterSelectors = new bytes4[](9);
        paymasterSelectors[0] = PaymasterFacet.initializePaymaster.selector;
        paymasterSelectors[1] = PaymasterFacet.validatePaymasterUserOp.selector;
        paymasterSelectors[2] = PaymasterFacet.postOp.selector;
        paymasterSelectors[3] = PaymasterFacet.setMonthlyLimit.selector;
        paymasterSelectors[4] = PaymasterFacet.resetMonthlyUsage.selector;
        paymasterSelectors[5] = PaymasterFacet.setAcceptedToken.selector;
        paymasterSelectors[6] = PaymasterFacet.depositNative.selector;
        paymasterSelectors[7] = PaymasterFacet.withdrawNative.selector;
        paymasterSelectors[8] = PaymasterFacet.getGasUsage.selector;
        cuts[6] = IDiamondCut.FacetCut({
            facetAddress: paymasterFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: paymasterSelectors
        });

        // SwapFacet
        bytes4[] memory swapSelectors = new bytes4[](4);
        swapSelectors[0] = SwapFacet.swapExactTokensForTokens.selector;
        swapSelectors[1] = SwapFacet.swapExactNativeForTokens.selector;
        swapSelectors[2] = SwapFacet.swapExactTokensForNative.selector;
        swapSelectors[3] = SwapFacet.getAmountsOut.selector;
        cuts[7] = IDiamondCut.FacetCut({
            facetAddress: swapFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: swapSelectors
        });

        // EscrowFacet
        bytes4[] memory escrowSelectors = new bytes4[](5);
        escrowSelectors[0] = EscrowFacet.lockCNGN.selector;
        escrowSelectors[1] = EscrowFacet.refundCNGN.selector;
        escrowSelectors[2] = EscrowFacet.completeEscrow.selector;
        escrowSelectors[3] = EscrowFacet.getEscrow.selector;
        escrowSelectors[4] = EscrowFacet.isEscrowLocked.selector;
        cuts[8] = IDiamondCut.FacetCut({
            facetAddress: escrowFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: escrowSelectors
        });

        // SwapEscrowFacet
        bytes4[] memory swapEscrowSelectors = new bytes4[](4);
        swapEscrowSelectors[0] = SwapEscrowFacet.depositAndLock.selector;
        swapEscrowSelectors[1] = SwapEscrowFacet.fulfillSwapToCNGN.selector;
        swapEscrowSelectors[2] = SwapEscrowFacet.refundDeposit.selector;
        swapEscrowSelectors[3] = SwapEscrowFacet.getDeposit.selector;
        cuts[9] = IDiamondCut.FacetCut({
            facetAddress: swapEscrowFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: swapEscrowSelectors
        });

        // SubscriptionFacet
        bytes4[] memory subscriptionSelectors = new bytes4[](4);
        subscriptionSelectors[0] = SubscriptionFacet.getTier.selector;
        subscriptionSelectors[1] = SubscriptionFacet.setTier.selector;
        subscriptionSelectors[2] = SubscriptionFacet.claimTrial.selector;
        subscriptionSelectors[3] = SubscriptionFacet.getUserTierDetails.selector;
        cuts[10] = IDiamondCut.FacetCut({
            facetAddress: subscriptionFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: subscriptionSelectors
        });

        // ConfigFacet
        bytes4[] memory configSelectors = new bytes4[](9);
        configSelectors[0] = ConfigFacet.initializeApp.selector;
        configSelectors[1] = ConfigFacet.setTreasury.selector;
        configSelectors[2] = ConfigFacet.setEntryPoint.selector;
        configSelectors[3] = ConfigFacet.setCNGN.selector;
        configSelectors[4] = ConfigFacet.setSupportedToken.selector;
        configSelectors[5] = ConfigFacet.getTreasury.selector;
        configSelectors[6] = ConfigFacet.getEntryPoint.selector;
        configSelectors[7] = ConfigFacet.getCNGN.selector;
        configSelectors[8] = ConfigFacet.getSupportedTokens.selector;
        cuts[11] = IDiamondCut.FacetCut({
            facetAddress: configFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: configSelectors
        });

        // ImportFacet
        bytes4[] memory importSelectors = new bytes4[](4);
        importSelectors[0] = ImportFacet.linkImportedAddress.selector;
        importSelectors[1] = ImportFacet.getImportInfo.selector;
        importSelectors[2] = ImportFacet.isAuthorizedSigner.selector;
        importSelectors[3] = ImportFacet.unlinkImportedAddress.selector;
        cuts[12] = IDiamondCut.FacetCut({
            facetAddress: importFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: importSelectors
        });

        return cuts;
    }
}
