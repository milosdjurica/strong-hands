// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract StrongHands {
    ////////////////////
    // * Errors 	  //
    ////////////////////
    error StrongHands__NotOwner(address msgSender, address owner);
    error StrongHands__ZeroDeposit();
    error StrongHands__ZeroAmount();
    error StrongHands__TransferFailed();

    ////////////////////
    // * Events 	  //
    ////////////////////
    event Deposited(address indexed user, uint256 indexed amount, uint256 indexed timestamp);
    event Withdrawn(address indexed user, uint256 indexed payout, uint256 indexed penalty, uint256 timestamp);

    ////////////////////
    // * Structs 	  //
    ////////////////////
    struct UserInfo {
        uint256 amount;
        uint256 lastDepositTimestamp;
        uint256 lastDividendPoints;
    }

    ////////////////////
    // * Constants	  //
    ////////////////////
    uint256 constant POINT_MULTIPLIER = 1e18;
    uint256 constant PENALTY_START_PERCENT = 50;

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
    mapping(address => UserInfo) public users;
    uint256 totalDividendPoints;
    uint256 unclaimedDividends;

    ////////////////////
    // * Modifiers 	  //
    ////////////////////
    modifier onlyOwner() {
        if (msg.sender != i_owner) revert StrongHands__NotOwner(msg.sender, i_owner);
        _;
    }

    modifier updateUser() {
        UserInfo storage user = users[msg.sender];
        uint256 owing = _dividendsOwing(msg.sender);
        if (owing > 0) {
            unclaimedDividends -= owing;
            user.amount += owing;
        }
        user.lastDividendPoints = totalDividendPoints;
        _;
    }

    function _dividendsOwing(address user) internal view returns (uint256) {
        uint256 newDividendPoints = totalDividendPoints - users[user].lastDividendPoints;
        return users[user].amount * newDividendPoints / POINT_MULTIPLIER;
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
    function deposit() external payable updateUser {
        if (msg.value == 0) revert StrongHands__ZeroDeposit();

        UserInfo storage user = users[msg.sender];
        user.amount += msg.value;
        user.lastDepositTimestamp = block.timestamp;

        totalStaked += msg.value;

        emit Deposited(msg.sender, msg.value, block.timestamp);
    }

    // must withdraw all, can not withdraw partially
    // penalty goes from 50% at start to the 0% at the end of lock period
    function withdraw() external updateUser {
        UserInfo storage user = users[msg.sender];
        uint256 initialAmount = user.amount;
        if (initialAmount == 0) revert StrongHands__ZeroAmount();

        uint256 penalty = calculatePenalty(msg.sender);

        user.amount = 0;
        totalStaked -= initialAmount;

        // TODO -> distribute penalty
        // TODO -> check reentrancy

        // transfer
        uint256 payout = initialAmount - penalty;
        (bool success,) = payable(msg.sender).call{value: payout}("");
        if (!success) revert StrongHands__TransferFailed();

        emit Withdrawn(msg.sender, payout, penalty, block.timestamp);
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

    // TODO -> Should this be public?
    function calculatePenalty(address userAddr) public view returns (uint256) {
        UserInfo memory user = users[userAddr];
        uint256 unlockTimestamp = user.lastDepositTimestamp + i_lockPeriod;
        if (block.timestamp >= unlockTimestamp) return 0;

        uint256 timeLeft = unlockTimestamp - block.timestamp;

        // rewritten formula to minimize precision loss
        // user.amount * (timeLeft/i_lockPeriod) * (50/100)
        // ==
        // (user.amount * timeLeft * 50) / (i_lockPeriod * 100)
        // ==
        // (user.amount * timeLeft) / (i_lockPeriod * 2)
        return (user.amount * timeLeft) / (i_lockPeriod * 2);
    }
}
