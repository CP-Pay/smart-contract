// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SessionKeyFacet {
    bytes32 constant SESSION_STORAGE_POSITION = keccak256("cppay.session.storage");

    struct Session {
        address creator;
        uint256 validUntil;
        uint256 maxAmount;
        uint256 spentAmount;
        bytes4[] allowedFunctions;
        bool revoked;
    }

    struct SessionKeyStorage {
        mapping(address => Session) sessions;
        mapping(address => address[]) userSessions;
    }

    function sessionStorage() internal pure returns (SessionKeyStorage storage ss) {
        bytes32 position = SESSION_STORAGE_POSITION;
        assembly {
            ss.slot := position
        }
    }

    event SessionCreated(address indexed sessionKey, address indexed creator, uint256 validUntil, uint256 maxAmount);
    event SessionExecuted(address indexed sessionKey, bytes4 indexed functionSelector, uint256 amount);
    event SessionRevoked(address indexed sessionKey);

    modifier onlyOwner() {
        bytes32 position = keccak256("cppay.account.storage");
        address owner_;
        assembly {
            mstore(0, position)
            owner_ := sload(keccak256(0, 32))
        }
        require(msg.sender == owner_, "Session: not owner");
        _;
    }

    function createSession(
        address sessionKey,
        uint256 duration,
        uint256 maxAmount,
        bytes4[] calldata allowedFunctions
    ) external onlyOwner {
        SessionKeyStorage storage ss = sessionStorage();
        
        require(sessionKey != address(0), "Session: zero address");
        require(duration > 0 && duration <= 7 days, "Session: invalid duration");
        require(maxAmount > 0, "Session: invalid amount");
        require(allowedFunctions.length > 0, "Session: no functions");

        Session storage session = ss.sessions[sessionKey];
        require(session.creator == address(0), "Session: already exists");

        session.creator = msg.sender;
        session.validUntil = block.timestamp + duration;
        session.maxAmount = maxAmount;
        session.spentAmount = 0;
        session.allowedFunctions = allowedFunctions;
        session.revoked = false;

        ss.userSessions[msg.sender].push(sessionKey);

        emit SessionCreated(sessionKey, msg.sender, session.validUntil, maxAmount);
    }

    function executeWithSession(
        address sessionKey,
        address dest,
        uint256 value,
        bytes calldata data
    ) external {
        SessionKeyStorage storage ss = sessionStorage();
        Session storage session = ss.sessions[sessionKey];
        
        require(msg.sender == sessionKey, "Session: unauthorized key");
        require(session.creator != address(0), "Session: not found");
        require(!session.revoked, "Session: revoked");
        require(block.timestamp <= session.validUntil, "Session: expired");
        require(session.spentAmount + value <= session.maxAmount, "Session: limit exceeded");

        bytes4 functionSelector = bytes4(data[:4]);
        bool functionAllowed = false;
        for (uint256 i = 0; i < session.allowedFunctions.length; i++) {
            if (session.allowedFunctions[i] == functionSelector) {
                functionAllowed = true;
                break;
            }
        }
        require(functionAllowed, "Session: function not allowed");

        session.spentAmount += value;

        (bool success, bytes memory result) = dest.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }

        emit SessionExecuted(sessionKey, functionSelector, value);
    }

    function revokeSession(address sessionKey) external onlyOwner {
        SessionKeyStorage storage ss = sessionStorage();
        Session storage session = ss.sessions[sessionKey];
        
        require(session.creator == msg.sender, "Session: not creator");
        require(!session.revoked, "Session: already revoked");

        session.revoked = true;
        emit SessionRevoked(sessionKey);
    }

    function getSession(address sessionKey)
        external
        view
        returns (
            address creator,
            uint256 validUntil,
            uint256 maxAmount,
            uint256 spentAmount,
            bool revoked,
            bytes4[] memory allowedFunctions
        )
    {
        Session storage session = sessionStorage().sessions[sessionKey];
        return (
            session.creator,
            session.validUntil,
            session.maxAmount,
            session.spentAmount,
            session.revoked,
            session.allowedFunctions
        );
    }

    function getUserSessions(address user) external view returns (address[] memory) {
        return sessionStorage().userSessions[user];
    }

    function isSessionValid(address sessionKey) external view returns (bool) {
        Session storage session = sessionStorage().sessions[sessionKey];
        return (
            session.creator != address(0) &&
            !session.revoked &&
            block.timestamp <= session.validUntil &&
            session.spentAmount < session.maxAmount
        );
    }
}
