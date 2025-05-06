// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract StrongHands {
    ////////////////////
    // * Errors 	  //
    ////////////////////
    error StrongHands__NotOwner(address msgSender, address owner);
    error StrongHands__ZeroDeposit();
    error StrongHands__ZeroAmount();

    ////////////////////
    // * Events 	  //
    ////////////////////
    event Deposited(address user, uint256 value, uint256 timestamp);

    ////////////////////
    // * Structs 	  //
    ////////////////////
    struct User {
        uint256 amount;
        uint256 lastDepositTimestamp;
    }

    ////////////////////
    // * Immutables	  //
    ////////////////////
    // fixed lock period duration (seconds)
    uint256 public immutable i_lockPeriod;
    // owner of the contract
    address public immutable i_owner;

    ////////////////////
    // * State        //
    ////////////////////
    // sum of all user.amount
    uint256 public totalStaked;
    // mapping of all users in the system
    mapping(address => User) public users;

    ////////////////////
    // * Modifiers 	  //
    ////////////////////
    modifier onlyOwner() {
        if (msg.sender != i_owner) revert StrongHands__NotOwner(msg.sender, i_owner);
        _;
    }

    ////////////////////
    // * Constructor  //
    ////////////////////
    constructor(uint256 _lockPeriod) {
        i_lockPeriod = _lockPeriod;
        i_owner = msg.sender;
    }

    ////////////////////
    // * External 	  //
    ////////////////////
    // can deposit multiple times
    // depositing starts new lock period counting for user
    function deposit() external payable {
        if (msg.value == 0) revert StrongHands__ZeroDeposit();

        User storage user = users[msg.sender];
        user.amount += msg.value;
        user.lastDepositTimestamp = block.timestamp;

        totalStaked += msg.value;

        emit Deposited(msg.sender, msg.value, block.timestamp);
    }

    // must withdraw all, can not withdraw partially
    // penalty goes from 50% at start to the 0% at the end of lock period
    function withdraw() external {
        if (users[msg.sender].amount == 0) revert StrongHands__ZeroAmount();

        users[msg.sender].amount = 0;
    }

    ////////////////////
    // * Only Owner   //
    ////////////////////
    // ONLY OWNER can call this function. He can call it at any moment
    function claimInterest() external onlyOwner {}

    ////////////////////
    // * Public 	  //
    ////////////////////

    ////////////////////
    // * Internal 	  //
    ////////////////////

    ////////////////////
    // * Private 	  //
    ////////////////////

    ////////////////////
    // * View & Pure  //
    ////////////////////
}
