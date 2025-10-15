// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibAppStorage.sol";
import "../libraries/LibDiamond.sol";

/**
 * @title SubscriptionFacet
 * @notice Manages user tiers and subscription status
 * @dev Tier 1 only for now, hooks for future Tier 2/3
 */
contract SubscriptionFacet {
    uint8 constant TIER_1 = 1;
    uint8 constant TIER_2 = 2;
    uint8 constant TIER_3 = 3;

    event TierUpdated(address indexed user, uint8 tier);
    event TrialClaimed(address indexed user);

    error InvalidTier();
    error TrialAlreadyClaimed();

    /**
     * @notice Get user's current tier
     * @param user The user address
     * @return tier The current tier (1, 2, or 3)
     */
    function getTier(address user) external view returns (uint8 tier) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        tier = s.userTiers[user].tier;

        // Default to Tier 1 if not set
        if (tier == 0) {
            tier = TIER_1;
        }
    }

    /**
     * @notice Set user's tier
     * @dev Only callable by contract owner
     * @param user The user address
     * @param tier The new tier
     */
    function setTier(address user, uint8 tier) external {
        LibDiamond.enforceIsContractOwner();

        if (tier < TIER_1 || tier > TIER_3) {
            revert InvalidTier();
        }

        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        s.userTiers[user].tier = tier;
        s.userTiers[user].lastUpdated = block.timestamp;

        emit TierUpdated(user, tier);
    }

    /**
     * @notice Claim trial status (placeholder for future use)
     * @dev Currently a no-op for Tier 1, but present for forward compatibility
     */
    function claimTrial() external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();

        if (s.userTiers[msg.sender].usedTrial) {
            revert TrialAlreadyClaimed();
        }

        s.userTiers[msg.sender].usedTrial = true;
        s.userTiers[msg.sender].tier = TIER_1;
        s.userTiers[msg.sender].lastUpdated = block.timestamp;

        emit TrialClaimed(msg.sender);
    }

    /**
     * @notice Check if user has claimed trial
     * @param user The user address
     * @return claimed True if trial was claimed
     */
    function hasClaimedTrial(address user) external view returns (bool claimed) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        return s.userTiers[user].usedTrial;
    }

    /**
     * @notice Get user tier details
     * @param user The user address
     * @return tier The user's tier
     * @return usedTrial Whether trial was used
     * @return lastUpdated Last update timestamp
     */
    function getUserTierDetails(address user) external view returns (uint8 tier, bool usedTrial, uint256 lastUpdated) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        LibAppStorage.UserTier storage userTier = s.userTiers[user];

        tier = userTier.tier == 0 ? TIER_1 : userTier.tier;
        usedTrial = userTier.usedTrial;
        lastUpdated = userTier.lastUpdated;
    }
}
