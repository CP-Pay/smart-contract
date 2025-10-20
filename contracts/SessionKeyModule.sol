// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library ECDSA {
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        if (signature.length != 65) {
            return address(0);
        }

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        if (v < 27) {
            v += 27;
        }
        if (v != 27 && v != 28) {
            return address(0);
        }

        address signer = ecrecover(hash, v, r, s);
        return signer;
    }
}

/**
 * @title SessionKeyModule
 * @notice Allows temporary session keys for batch transactions
 * @dev Enables one-time PIN/biometric approval for multiple transactions
 */
contract SessionKeyModule {
    using ECDSA for bytes32;
    
    struct SessionKeyData {
        address sessionKey;
        uint48 validUntil;
        uint48 validAfter;
        uint256 sessionId;
        bool isActive;
    }
    
    // smartAccount => sessionId => SessionKeyData
    mapping(address => mapping(uint256 => SessionKeyData)) public sessions;
    
    // smartAccount => current session count
    mapping(address => uint256) public sessionCount;
    
    // Events
    event SessionKeyCreated(
        address indexed smartAccount,
        address indexed sessionKey,
        uint256 sessionId,
        uint48 validUntil
    );
    
    event SessionKeyRevoked(
        address indexed smartAccount,
        uint256 sessionId
    );
    
    event SessionKeyUsed(
        address indexed smartAccount,
        uint256 sessionId,
        bytes32 txHash
    );
    
    /**
     * @notice Create a new session key
     * @param sessionKey Temporary key address
     * @param validDuration How long the session is valid (in seconds)
     */
    function createSessionKey(
        address sessionKey,
        uint48 validDuration
    ) external returns (uint256 sessionId) {
        require(sessionKey != address(0), "Invalid session key");
        require(validDuration > 0 && validDuration <= 1 days, "Invalid duration");
        
        sessionId = sessionCount[msg.sender]++;
        
        sessions[msg.sender][sessionId] = SessionKeyData({
            sessionKey: sessionKey,
            validUntil: uint48(block.timestamp + validDuration),
            validAfter: uint48(block.timestamp),
            sessionId: sessionId,
            isActive: true
        });
        
        emit SessionKeyCreated(
            msg.sender,
            sessionKey,
            sessionId,
            uint48(block.timestamp + validDuration)
        );
    }
    
    /**
     * @notice Validate a session key signature
     * @param smartAccount The smart account address
     * @param sessionId The session ID
     * @param txHash Transaction hash being signed
     * @param signature Signature from session key
     */
    function validateSessionKey(
        address smartAccount,
        uint256 sessionId,
        bytes32 txHash,
        bytes memory signature
    ) external view returns (bool) {
        SessionKeyData memory session = sessions[smartAccount][sessionId];
        
        // Check session validity
        if (!session.isActive) return false;
        if (block.timestamp < session.validAfter) return false;
        if (block.timestamp > session.validUntil) return false;
        
        // Verify signature
        address signer = txHash.toEthSignedMessageHash().recover(signature);
        
        if (signer == session.sessionKey) {
            return true;
        }
        
        return false;
    }
    
    /**
     * @notice Revoke a session key
     */
    function revokeSessionKey(uint256 sessionId) external {
        require(sessions[msg.sender][sessionId].isActive, "Session not active");
        
        sessions[msg.sender][sessionId].isActive = false;
        
        emit SessionKeyRevoked(msg.sender, sessionId);
    }
    
    /**
     * @notice Get session key details
     */
    function getSessionKey(address smartAccount, uint256 sessionId) 
        external 
        view 
        returns (SessionKeyData memory) 
    {
        return sessions[smartAccount][sessionId];
    }
    
    /**
     * @notice Check if session key is valid
     */
    function isSessionKeyValid(address smartAccount, uint256 sessionId) 
        external 
        view 
        returns (bool) 
    {
        SessionKeyData memory session = sessions[smartAccount][sessionId];
        
        return session.isActive 
            && block.timestamp >= session.validAfter 
            && block.timestamp <= session.validUntil;
    }
}