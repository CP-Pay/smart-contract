// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract UtilityFacet {
    bytes32 constant UTILITY_STORAGE_POSITION = keccak256("cppay.utility.storage");

    struct UtilityStorage {
        bool paused;
        mapping(address => bool) admins;
        mapping(address => bool) blacklisted;
        uint256 emergencyWithdrawalDelay;
        mapping(address => uint256) emergencyWithdrawalRequests;
    }

    function utilityStorage() internal pure returns (UtilityStorage storage us) {
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
    event EmergencyWithdrawalRequested(address indexed user, uint256 executeAfter);
    event EmergencyWithdrawalExecuted(address indexed user, uint256 amount);

    modifier onlyAdmin() {
        require(utilityStorage().admins[msg.sender], "Utility: not admin");
        _;
    }

    modifier whenNotPaused() {
        require(!utilityStorage().paused, "Utility: paused");
        _;
    }

    modifier notBlacklisted(address user) {
        require(!utilityStorage().blacklisted[user], "Utility: user blacklisted");
        _;
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
