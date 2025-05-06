// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract StrongHands {
    error StrongHands__NotOwner(address msgSender, address owner);
    error StrongHands__ZeroDeposit();
    error StrongHands__ZeroAmount();

    // TODO ->  events for deposit, withdraw and claimInterest

    uint256 public immutable i_lockPeriod;
    address public immutable i_owner;

    struct User {
        uint256 amount;
        uint256 lastTimeDeposited;
    }

    mapping(address => User) users;

    constructor(uint256 _lockPeriod) {
        i_lockPeriod = _lockPeriod;
        i_owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) revert StrongHands__NotOwner(msg.sender, i_owner);
        _;
    }

    // can deposit multiple times
    // depositing starts new lock period counting for user
    function deposit() external payable {
        if (msg.value == 0) revert StrongHands__ZeroDeposit();

        users[msg.sender].amount += msg.value;
        users[msg.sender].lastTimeDeposited = block.timestamp;
    }

    // must withdraw all, can not withdraw partially
    // penalty goes from 50% at start to the 0% at the end of lock period
    function withdraw() external {
        if (users[msg.sender].amount == 0) revert StrongHands__ZeroAmount();

        users[msg.sender].amount = 0;
    }

    // ONLY OWNER can call this function. He can call it at any moment
    function claimInterest() external onlyOwner {}
}
