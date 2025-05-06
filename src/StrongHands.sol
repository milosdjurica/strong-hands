// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract StrongHands {
    error StrongHands__NotOwner(address msgSender, address owner);

    // TODO ->  events for deposit, withdraw and claimInterest

    uint256 public immutable i_lockPeriod;
    address public immutable i_owner;

    constructor(uint256 _lockPeriod) {
        i_lockPeriod = _lockPeriod;
        i_owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) revert StrongHands__NotOwner(msg.sender, i_owner);
        _;
    }

    function deposit() external payable {
        // can deposit multiple times
        // depositing starts new lock period counting for user
        // penalty goes from 50% at start to the 0% at the end of lock period
    }

    function withdraw() external {
        // must withdraw all, can not withdraw partially
    }

    function claimInterest() external onlyOwner {
        // ONLY OWNER can call this function. He can call it at any moment
    }
}
