// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract BurnerChat {
    struct User {
        string username;
        string publicKey; // Hex string of the public key (uncompressed usually)
        bool exists;
    }

    mapping(address => User) public users;
    mapping(string => address) public usernameToAddress;

    // Events
    event NewMessage(address indexed sender, address indexed receiver, string message, uint256 timestamp);
    event UserRegistered(address indexed user, string username, string publicKey);

    function registerUsername(string memory _username, string memory _publicKey) public {
        require(bytes(_username).length > 0, "Username cannot be empty");
        require(bytes(_publicKey).length > 0, "Public Key cannot be empty");
        require(usernameToAddress[_username] == address(0), "Username already taken");
        require(!users[msg.sender].exists, "User already registered");

        users[msg.sender] = User(_username, _publicKey, true);
        usernameToAddress[_username] = msg.sender;

        emit UserRegistered(msg.sender, _username, _publicKey);
    }

    function sendMessage(address _to, string memory _message) public {
        emit NewMessage(msg.sender, _to, _message, block.timestamp);
    }
    
    function getAddressByUsername(string memory _username) public view returns (address) {
        return usernameToAddress[_username];
    }

    function getUsernameByAddress(address _user) public view returns (string memory) {
        return users[_user].username;
    }
    
    function getPublicKeyByAddress(address _user) public view returns (string memory) {
        return users[_user].publicKey;
    }
}
