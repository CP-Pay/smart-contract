// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibDiamond.sol";

contract UtilityFacet {
    bytes32 constant UTILITY_STORAGE_POSITION =
        keccak256("cppay.utility.storage");

    struct UtilityStorage {
        bool paused;
        bool initialized;
        mapping(address => bool) admins;
        mapping(address => bool) blacklisted;
        uint256 emergencyWithdrawalDelay;
        mapping(address => uint256) emergencyWithdrawalRequests;
    }

    function utilityStorage()
        internal
        pure
        returns (UtilityStorage storage us)
    {
        bytes32 position = UTILITY_STORAGE_POSITION;
        assembly {
            us.slot := position
        }
    }

    event Paused(address indexed admin);
    event Unpaused(address indexed admin);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event UserBlacklisted(address indexed user);
    event UserWhitelisted(address indexed user);
    event EmergencyWithdrawalRequested(
        address indexed user,
        uint256 executeAfter
    );
    event EmergencyWithdrawalExecuted(address indexed user, uint256 amount);
    event UtilityInitialized(address indexed initialAdmin);

    modifier onlyAdmin() {
        require(utilityStorage().admins[msg.sender], "Utility: not admin");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == LibDiamond.contractOwner(), "Utility: not owner");
        _;
    }

    modifier whenNotPaused() {
        require(!utilityStorage().paused, "Utility: paused");
        _;
    }

    modifier notBlacklisted(address user) {
        require(
            !utilityStorage().blacklisted[user],
            "Utility: user blacklisted"
        );
        _;
    }

    /**
     * @notice Initialize the UtilityFacet with the contract owner as the first admin
     * @dev Can only be called once, and only by the contract owner
     */
    function initializeUtility() external onlyOwner {
        UtilityStorage storage us = utilityStorage();
        require(!us.initialized, "Utility: already initialized");

        address owner = LibDiamond.contractOwner();
        us.admins[owner] = true;
        us.emergencyWithdrawalDelay = 48 hours;
        us.initialized = true;

        emit UtilityInitialized(owner);
        emit AdminAdded(owner);
    }

    function pause() external onlyAdmin {
        utilityStorage().paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyAdmin {
        utilityStorage().paused = false;
        emit Unpaused(msg.sender);
    }

    function addAdmin(address admin) external onlyAdmin {
        utilityStorage().admins[admin] = true;
        emit AdminAdded(admin);
    }

    function removeAdmin(address admin) external onlyAdmin {
        utilityStorage().admins[admin] = false;
        emit AdminRemoved(admin);
    }

    function blacklistUser(address user) external onlyAdmin {
        utilityStorage().blacklisted[user] = true;
        emit UserBlacklisted(user);
    }

    function whitelistUser(address user) external onlyAdmin {
        utilityStorage().blacklisted[user] = false;
        emit UserWhitelisted(user);
    }

    function requestEmergencyWithdrawal() external {
        UtilityStorage storage us = utilityStorage();
        uint256 executeAfter = block.timestamp + us.emergencyWithdrawalDelay;
        us.emergencyWithdrawalRequests[msg.sender] = executeAfter;
        emit EmergencyWithdrawalRequested(msg.sender, executeAfter);
    }

    function executeEmergencyWithdrawal() external {
        UtilityStorage storage us = utilityStorage();
        uint256 executeAfter = us.emergencyWithdrawalRequests[msg.sender];

        require(executeAfter > 0, "Utility: no request");
        require(block.timestamp >= executeAfter, "Utility: delay not passed");

        uint256 balance = address(this).balance;
        require(balance > 0, "Utility: no balance");

        delete us.emergencyWithdrawalRequests[msg.sender];

        payable(msg.sender).transfer(balance);

        emit EmergencyWithdrawalExecuted(msg.sender, balance);
    }

    function isPaused() external view returns (bool) {
        return utilityStorage().paused;
    }

    function isAdmin(address user) external view returns (bool) {
        return utilityStorage().admins[user];
    }

    function isBlacklisted(address user) external view returns (bool) {
        return utilityStorage().blacklisted[user];
    }
}
