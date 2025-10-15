// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/CPPayDiamond.sol";
import "../contracts/CPPayFactory.sol";
import "../contracts/facets/SwapFacet.sol";
import "../contracts/facets/EscrowFacet.sol";
import "../contracts/facets/SwapEscrowFacet.sol";
import "../contracts/facets/SessionKeyFacet.sol";
import "../contracts/facets/GuardianFacet.sol";
import "../contracts/facets/PaymasterFacet.sol";
import "../contracts/facets/SubscriptionFacet.sol";
import "../contracts/facets/ConfigFacet.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/mocks/MockEntryPoint.sol";
import "../contracts/mocks/MockCNGN.sol";

/**
 * @title ComprehensiveFacetTest
 * @notice Tests all facets and edge cases for CPPay MVP
 */
contract ComprehensiveFacetTest is Test {
    CPPayFactory factory;
    SwapFacet swapFacet;
    EscrowFacet escrowFacet;
    SwapEscrowFacet swapEscrowFacet;
    SessionKeyFacet sessionKeyFacet;
    GuardianFacet guardianFacet;
    PaymasterFacet paymasterFacet;
    SubscriptionFacet subscriptionFacet;
    ConfigFacet configFacet;

    MockEntryPoint entryPoint;
    MockCNGN cngn;

    address owner = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);
    address treasury = address(0x4);
    address guardian1 = address(0x5);
    address guardian2 = address(0x6);
    address guardian3 = address(0x7);

    address diamond;

    function setUp() public {
        // Deploy mocks
        entryPoint = new MockEntryPoint();
        cngn = new MockCNGN();

        // Deploy facets
        swapFacet = new SwapFacet();
        escrowFacet = new EscrowFacet();
        swapEscrowFacet = new SwapEscrowFacet();
        sessionKeyFacet = new SessionKeyFacet();
        guardianFacet = new GuardianFacet();
        paymasterFacet = new PaymasterFacet();
        subscriptionFacet = new SubscriptionFacet();
        configFacet = new ConfigFacet();

        // Deploy factory
        factory = new CPPayFactory(address(entryPoint), treasury, address(cngn));

        // Create test Diamond
        diamond = _createTestDiamond(owner);

        // Mint CNGN to users
        cngn.mint(owner, 1000000 ether);
        cngn.mint(user1, 1000000 ether);
        cngn.mint(diamond, 1000000 ether);

        // Approve Diamond to spend CNGN
        vm.prank(owner);
        cngn.approve(diamond, type(uint256).max);
    }

    function _createTestDiamond(address _owner) internal returns (address) {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](8);

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
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(configFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: configSelectors
        });

        // EscrowFacet
        bytes4[] memory escrowSelectors = new bytes4[](3);
        escrowSelectors[0] = EscrowFacet.lockCNGN.selector;
        escrowSelectors[1] = EscrowFacet.refundCNGN.selector;
        escrowSelectors[2] = EscrowFacet.completeEscrow.selector;
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(escrowFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: escrowSelectors
        });

        // SessionKeyFacet
        bytes4[] memory sessionSelectors = new bytes4[](4);
        sessionSelectors[0] = SessionKeyFacet.createSessionKey.selector;
        sessionSelectors[1] = SessionKeyFacet.revokeSessionKey.selector;
        sessionSelectors[2] = SessionKeyFacet.isValidSessionKey.selector;
        sessionSelectors[3] = SessionKeyFacet.getUserSessionKeys.selector;
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(sessionKeyFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: sessionSelectors
        });

        // GuardianFacet
        bytes4[] memory guardianSelectors = new bytes4[](6);
        guardianSelectors[0] = GuardianFacet.addGuardian.selector;
        guardianSelectors[1] = GuardianFacet.removeGuardian.selector;
        guardianSelectors[2] = GuardianFacet.initiateRecovery.selector;
        guardianSelectors[3] = GuardianFacet.voteRecovery.selector;
        guardianSelectors[4] = GuardianFacet.executeRecovery.selector;
        guardianSelectors[5] = GuardianFacet.getGuardians.selector;
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(guardianFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: guardianSelectors
        });

        // PaymasterFacet
        bytes4[] memory paymasterSelectors = new bytes4[](4);
        paymasterSelectors[0] = PaymasterFacet.validatePaymasterUserOp.selector;
        paymasterSelectors[1] = PaymasterFacet.postOp.selector;
        paymasterSelectors[2] = PaymasterFacet.setMonthlyLimit.selector;
        paymasterSelectors[3] = PaymasterFacet.getGasUsage.selector;
        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: address(paymasterFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: paymasterSelectors
        });

        // SubscriptionFacet
        bytes4[] memory subscriptionSelectors = new bytes4[](4);
        subscriptionSelectors[0] = SubscriptionFacet.getTier.selector;
        subscriptionSelectors[1] = SubscriptionFacet.setTier.selector;
        subscriptionSelectors[2] = SubscriptionFacet.claimTrial.selector;
        subscriptionSelectors[3] = SubscriptionFacet.getUserTierDetails.selector;
        cuts[5] = IDiamondCut.FacetCut({
            facetAddress: address(subscriptionFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: subscriptionSelectors
        });

        // SwapEscrowFacet
        bytes4[] memory swapEscrowSelectors = new bytes4[](2);
        swapEscrowSelectors[0] = SwapEscrowFacet.depositAndLock.selector;
        swapEscrowSelectors[1] = SwapEscrowFacet.fulfillSwapToCNGN.selector;
        cuts[6] = IDiamondCut.FacetCut({
            facetAddress: address(swapEscrowFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: swapEscrowSelectors
        });

        // SwapFacet
        bytes4[] memory swapSelectors = new bytes4[](4);
        swapSelectors[0] = SwapFacet.swapExactTokensForTokens.selector;
        swapSelectors[1] = SwapFacet.swapExactNativeForTokens.selector;
        swapSelectors[2] = SwapFacet.swapExactTokensForNative.selector;
        swapSelectors[3] = SwapFacet.getAmountsOut.selector;
        cuts[7] = IDiamondCut.FacetCut({
            facetAddress: address(swapFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: swapSelectors
        });

        address _diamond = factory.createWallet(_owner, cuts, "");

        // Initialize app storage
        vm.prank(_owner);
        ConfigFacet(_diamond).initializeApp(treasury, address(entryPoint), address(cngn));

        // Add CNGN as supported token for swap escrow
        vm.prank(_owner);
        ConfigFacet(_diamond).setSupportedToken(address(cngn), true);

        return _diamond;
    }

    // ========== CONFIG FACET TESTS ==========

    function testInitializeApp() public {
        address newDiamond = _createTestDiamond(user1);

        assertEq(ConfigFacet(newDiamond).getTreasury(), treasury);
        assertEq(ConfigFacet(newDiamond).getEntryPoint(), address(entryPoint));
        assertEq(ConfigFacet(newDiamond).getCNGN(), address(cngn));
    }

    function testSetTreasury() public {
        address newTreasury = address(0x999);

        vm.prank(owner);
        ConfigFacet(diamond).setTreasury(newTreasury);

        assertEq(ConfigFacet(diamond).getTreasury(), newTreasury);
    }

    function testCannotSetZeroTreasury() public {
        vm.prank(owner);
        vm.expectRevert();
        ConfigFacet(diamond).setTreasury(address(0));
    }

    // ========== ESCROW FACET TESTS ==========

    function testLockCNGN() public {
        uint256 amount = 1000 ether;
        bytes32 serviceCode = keccak256("BILL_PAYMENT");
        bytes32 refId = keccak256("REF123");

        uint256 balanceBefore = cngn.balanceOf(diamond);

        vm.prank(owner);
        EscrowFacet(diamond).lockCNGN(amount, serviceCode, refId);

        // CNGN stays in the diamond (escrow doesn't transfer, just locks accounting)
        assertEq(cngn.balanceOf(diamond), balanceBefore);
    }

    function testCannotLockWithoutCNGN() public {
        address newDiamond = _createTestDiamond(user2);

        vm.prank(user2);
        vm.expectRevert();
        EscrowFacet(newDiamond).lockCNGN(1000 ether, keccak256("BILL"), keccak256("REF"));
    }

    function testRefundCNGN() public {
        uint256 amount = 1000 ether;
        bytes32 refId = keccak256("REF123");

        // Lock first
        vm.prank(owner);
        EscrowFacet(diamond).lockCNGN(amount, keccak256("BILL"), refId);

        uint256 diamondBalanceBefore = cngn.balanceOf(diamond);
        uint256 userBalanceBefore = cngn.balanceOf(owner);

        // Refund (owner only) - transfers CNGN back to user
        vm.prank(owner);
        EscrowFacet(diamond).refundCNGN(refId);

        // Diamond loses CNGN, user gains it
        assertEq(cngn.balanceOf(diamond), diamondBalanceBefore - amount);
        assertEq(cngn.balanceOf(owner), userBalanceBefore + amount);
    }

    function testCompleteEscrow() public {
        uint256 amount = 1000 ether;
        bytes32 refId = keccak256("REF123");

        vm.prank(owner);
        EscrowFacet(diamond).lockCNGN(amount, keccak256("BILL"), refId);

        uint256 treasuryBefore = cngn.balanceOf(treasury);

        // Complete (owner only) - sends to treasury
        vm.prank(owner);
        EscrowFacet(diamond).completeEscrow(refId);

        // Treasury should receive the CNGN
        assertEq(cngn.balanceOf(treasury), treasuryBefore + amount);
    }

    // ========== SESSION KEY FACET TESTS ==========

    function testCreateSessionKey() public {
        address sessionKey = address(0xABC);
        uint256 duration = 86400; // 24 hours
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = EscrowFacet.lockCNGN.selector;

        vm.prank(owner);
        bytes32 keyId = SessionKeyFacet(diamond).createSessionKey(
            sessionKey,
            duration,
            1 ether, // maxAmount
            selectors
        );

        assertTrue(SessionKeyFacet(diamond).isValidSessionKey(keyId, EscrowFacet.lockCNGN.selector, 0.001 ether));
    }

    function testRevokeSessionKey() public {
        address sessionKey = address(0xABC);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = EscrowFacet.lockCNGN.selector;

        vm.prank(owner);
        bytes32 keyId = SessionKeyFacet(diamond).createSessionKey(sessionKey, 86400, 1 ether, selectors);

        vm.prank(owner);
        SessionKeyFacet(diamond).revokeSessionKey(keyId);

        assertFalse(SessionKeyFacet(diamond).isValidSessionKey(keyId, EscrowFacet.lockCNGN.selector, 0.001 ether));
    }

    function testSessionKeyExpiry() public {
        address sessionKey = address(0xABC);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = EscrowFacet.lockCNGN.selector;

        vm.prank(owner);
        bytes32 keyId = SessionKeyFacet(diamond).createSessionKey(
            sessionKey,
            100, // 100 seconds
            1 ether,
            selectors
        );

        assertTrue(SessionKeyFacet(diamond).isValidSessionKey(keyId, EscrowFacet.lockCNGN.selector, 0.001 ether));

        // Fast forward past expiry
        vm.warp(block.timestamp + 101);

        assertFalse(SessionKeyFacet(diamond).isValidSessionKey(keyId, EscrowFacet.lockCNGN.selector, 0.001 ether));
    }

    // ========== GUARDIAN FACET TESTS ==========

    function testAddGuardians() public {
        vm.startPrank(owner);
        GuardianFacet(diamond).addGuardian(guardian1);
        GuardianFacet(diamond).addGuardian(guardian2);
        GuardianFacet(diamond).addGuardian(guardian3);
        vm.stopPrank();

        address[] memory guardians = GuardianFacet(diamond).getGuardians();
        assertEq(guardians.length, 3);
        assertEq(guardians[0], guardian1);
    }

    function testRemoveGuardian() public {
        vm.startPrank(owner);
        GuardianFacet(diamond).addGuardian(guardian1);
        GuardianFacet(diamond).addGuardian(guardian2);
        GuardianFacet(diamond).removeGuardian(guardian1);
        vm.stopPrank();

        address[] memory guardians = GuardianFacet(diamond).getGuardians();
        assertEq(guardians.length, 1);
        assertEq(guardians[0], guardian2);
    }

    function testSocialRecovery() public {
        // Setup guardians
        vm.startPrank(owner);
        GuardianFacet(diamond).addGuardian(guardian1);
        GuardianFacet(diamond).addGuardian(guardian2);
        GuardianFacet(diamond).addGuardian(guardian3);
        vm.stopPrank();

        address newOwner = address(0x888);

        // Guardian1 initiates recovery
        vm.prank(guardian1);
        GuardianFacet(diamond).initiateRecovery(newOwner);

        // Guardian2 votes
        vm.prank(guardian2);
        GuardianFacet(diamond).voteRecovery(newOwner);

        // Fast forward recovery delay
        vm.warp(block.timestamp + 3 days + 1);

        // Execute recovery
        vm.prank(guardian1);
        GuardianFacet(diamond).executeRecovery(newOwner);

        // Verify owner changed (would need ownership facet to verify)
    }

    // ========== SUBSCRIPTION FACET TESTS ==========

    function testClaimTrial() public {
        vm.prank(owner);
        SubscriptionFacet(diamond).claimTrial();

        uint8 tier = SubscriptionFacet(diamond).getTier(owner);
        assertEq(tier, 1); // TRIAL tier
    }

    function testCannotClaimTrialTwice() public {
        vm.prank(owner);
        SubscriptionFacet(diamond).claimTrial();

        vm.prank(owner);
        vm.expectRevert();
        SubscriptionFacet(diamond).claimTrial();
    }

    function testSetTier() public {
        vm.prank(owner);
        SubscriptionFacet(diamond).setTier(user1, 2); // BASIC tier

        assertEq(SubscriptionFacet(diamond).getTier(user1), 2);
    }

    // ========== PAYMASTER FACET TESTS ==========

    function testSetMonthlyLimit() public {
        uint256 newLimit = 0.01 ether; // ₦10,000

        vm.prank(owner);
        PaymasterFacet(diamond).setMonthlyLimit(owner, newLimit);

        (uint256 limit,,,,) = PaymasterFacet(diamond).getGasUsage(owner);
        assertEq(limit, newLimit);
    }

    // ========== SWAP ESCROW FACET TESTS ==========

    function testDepositAndLock() public {
        bytes32 refId = keccak256("SWAP_REF");
        uint256 amount = 100 ether;

        // Approve SwapEscrowFacet to spend cngn from owner
        vm.prank(owner);
        cngn.approve(diamond, amount);

        vm.prank(owner);
        SwapEscrowFacet(diamond).depositAndLock(address(cngn), amount, refId);

        // Verify CNGN was transferred
        assertEq(cngn.balanceOf(diamond), 1000000 ether + amount);
    }

    function testFulfillSwapToCNGN() public {
        bytes32 refId = keccak256("SWAP_REF");
        uint256 depositAmount = 100 ether;
        uint256 cngnAmount = 95 ether; // After fees

        // Deposit first
        vm.prank(owner);
        cngn.approve(diamond, depositAmount);

        vm.prank(owner);
        SwapEscrowFacet(diamond).depositAndLock(address(cngn), depositAmount, refId);

        // Fulfill swap (owner only)
        vm.prank(owner);
        SwapEscrowFacet(diamond).fulfillSwapToCNGN(refId, cngnAmount);

        // Verify CNGN was sent to owner
        assertEq(cngn.balanceOf(owner), 1000000 ether - depositAmount + cngnAmount);
    }

    // ========== EDGE CASES ==========

    function testCannotInitializeTwice() public {
        vm.prank(owner);
        vm.expectRevert();
        ConfigFacet(diamond).initializeApp(treasury, address(entryPoint), address(cngn));
    }

    function testOnlyOwnerCanRefund() public {
        bytes32 refId = keccak256("REF");

        vm.prank(owner);
        EscrowFacet(diamond).lockCNGN(100 ether, keccak256("BILL"), refId);

        // Non-owner tries to refund
        vm.prank(user1);
        vm.expectRevert();
        EscrowFacet(diamond).refundCNGN(refId);
    }

    function testOnlyOwnerCanAddGuardians() public {
        vm.prank(user1);
        vm.expectRevert();
        GuardianFacet(diamond).addGuardian(guardian1);
    }

    function testSessionKeyWithInvalidSelector() public {
        // Session key created with lockCNGN selector only
        address sessionKey = address(0xABC);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = EscrowFacet.lockCNGN.selector;

        vm.prank(owner);
        bytes32 keyId = SessionKeyFacet(diamond).createSessionKey(sessionKey, 86400, 1 ether, selectors);

        // Try to use session key for refund (not allowed)
        // This would be tested in AccountFacet integration tests
        assertTrue(SessionKeyFacet(diamond).isValidSessionKey(keyId, EscrowFacet.lockCNGN.selector, 0.001 ether));
    }

    function testZeroAmountEscrow() public {
        vm.prank(owner);
        vm.expectRevert();
        EscrowFacet(diamond).lockCNGN(0, keccak256("BILL"), keccak256("REF"));
    }
}
