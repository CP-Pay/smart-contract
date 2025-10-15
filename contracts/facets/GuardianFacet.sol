// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibDiamond.sol";

contract GuardianFacet {
    bytes32 constant GUARDIAN_STORAGE_POSITION = keccak256("cppay.guardian.storage");

    struct RecoveryRequest {
        address newOwner;
        uint256 votesReceived;
        mapping(address => bool) hasVoted;
        uint256 executeAfter;
        bool executed;
    }

    struct GuardianStorage {
        address[] guardians;
        mapping(address => bool) isGuardian;
        uint256 threshold;
        mapping(address => RecoveryRequest) recoveryRequests;
    }

    function guardianStorage() internal pure returns (GuardianStorage storage gs) {
        bytes32 position = GUARDIAN_STORAGE_POSITION;
        assembly {
            gs.slot := position
        }
    }

    uint256 constant RECOVERY_DELAY = 48 hours;
    uint256 constant MAX_GUARDIANS = 10;
    uint256 constant MIN_THRESHOLD = 2;

    event GuardianAdded(address indexed guardian);
    event GuardianRemoved(address indexed guardian);
    event ThresholdChanged(uint256 newThreshold);
    event RecoveryInitiated(address indexed newOwner, uint256 executeAfter);
    event RecoveryVoted(address indexed guardian, address indexed newOwner);
    event RecoveryExecuted(address indexed oldOwner, address indexed newOwner);
    event RecoveryCancelled(address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == LibDiamond.contractOwner(), "Guardian: not owner");
        _;
    }

    modifier onlyGuardian() {
        require(guardianStorage().isGuardian[msg.sender], "Guardian: not a guardian");
        _;
    }

    function addGuardian(address guardian) external onlyOwner {
        GuardianStorage storage gs = guardianStorage();
        require(guardian != address(0), "Guardian: zero address");
        require(!gs.isGuardian[guardian], "Guardian: already added");
        require(gs.guardians.length < MAX_GUARDIANS, "Guardian: max guardians reached");

        gs.guardians.push(guardian);
        gs.isGuardian[guardian] = true;
        emit GuardianAdded(guardian);
    }

    function removeGuardian(address guardian) external onlyOwner {
        GuardianStorage storage gs = guardianStorage();
        require(gs.isGuardian[guardian], "Guardian: not a guardian");

        for (uint256 i = 0; i < gs.guardians.length; i++) {
            if (gs.guardians[i] == guardian) {
                gs.guardians[i] = gs.guardians[gs.guardians.length - 1];
                gs.guardians.pop();
                break;
            }
        }

        gs.isGuardian[guardian] = false;

        if (gs.threshold > gs.guardians.length) {
            gs.threshold = gs.guardians.length;
        }

        emit GuardianRemoved(guardian);
    }

    function setThreshold(uint256 newThreshold) external onlyOwner {
        GuardianStorage storage gs = guardianStorage();
        require(newThreshold >= MIN_THRESHOLD && newThreshold <= gs.guardians.length, "Guardian: invalid threshold");
        gs.threshold = newThreshold;
        emit ThresholdChanged(newThreshold);
    }

    function initiateRecovery(address newOwner) external onlyGuardian {
        GuardianStorage storage gs = guardianStorage();
        RecoveryRequest storage request = gs.recoveryRequests[newOwner];

        require(newOwner != address(0), "Guardian: zero address");
        require(request.votesReceived == 0, "Guardian: recovery already initiated");

        request.newOwner = newOwner;
        request.executeAfter = block.timestamp + RECOVERY_DELAY;
        request.hasVoted[msg.sender] = true;
        request.votesReceived = 1;

        emit RecoveryInitiated(newOwner, request.executeAfter);
        emit RecoveryVoted(msg.sender, newOwner);
    }

    function voteRecovery(address newOwner) external onlyGuardian {
        GuardianStorage storage gs = guardianStorage();
        RecoveryRequest storage request = gs.recoveryRequests[newOwner];

        require(newOwner != address(0), "Guardian: zero address");
        require(request.newOwner == newOwner, "Guardian: recovery not initiated");
        require(!request.hasVoted[msg.sender], "Guardian: already voted");
        require(!request.executed, "Guardian: already executed");

        request.hasVoted[msg.sender] = true;
        request.votesReceived++;

        emit RecoveryVoted(msg.sender, newOwner);
    }

    function executeRecovery(address newOwner) external {
        GuardianStorage storage gs = guardianStorage();
        RecoveryRequest storage request = gs.recoveryRequests[newOwner];

        require(request.votesReceived >= gs.threshold, "Guardian: threshold not reached");
        require(block.timestamp >= request.executeAfter, "Guardian: delay not passed");
        require(!request.executed, "Guardian: already executed");

        address oldOwner = LibDiamond.contractOwner();
        LibDiamond.setContractOwner(newOwner);

        request.executed = true;
        emit RecoveryExecuted(oldOwner, newOwner);
    }

    function cancelRecovery(address newOwner) external onlyOwner {
        GuardianStorage storage gs = guardianStorage();
        RecoveryRequest storage request = gs.recoveryRequests[newOwner];

        require(request.votesReceived > 0, "Guardian: no active recovery");
        require(!request.executed, "Guardian: already executed");

        delete gs.recoveryRequests[newOwner];
        emit RecoveryCancelled(newOwner);
    }

    function getGuardians() external view returns (address[] memory) {
        return guardianStorage().guardians;
    }

    function getThreshold() external view returns (uint256) {
        return guardianStorage().threshold;
    }

    function getRecoveryRequest(address newOwner)
        external
        view
        returns (uint256 votesReceived, uint256 executeAfter, bool executed)
    {
        RecoveryRequest storage request = guardianStorage().recoveryRequests[newOwner];
        return (request.votesReceived, request.executeAfter, request.executed);
    }
}
