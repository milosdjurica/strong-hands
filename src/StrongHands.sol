// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IWrappedTokenGatewayV3} from "./interfaces/IWrappedTokenGatewayV3.sol";

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
        uint256 balance;
        uint256 lastDepositTimestamp;
        uint256 lastDividendPoints;
    }

    ////////////////////
    // * Constants	  //
    ////////////////////
    uint256 constant POINT_MULTIPLIER = 1e18;
    uint256 constant PENALTY_START_PERCENT = 50;
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;

    ////////////////////
    // * Immutables	  //
    ////////////////////
    // fixed lock period duration (seconds)
    uint256 public immutable i_lockPeriod;
    // owner of the contract
    address public immutable i_owner;
    IWrappedTokenGatewayV3 public immutable i_aaveWrappedTokenGatewayV3;

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

    ////////////////////
    // * Constructor  //
    ////////////////////
    constructor(uint256 _lockPeriod, IWrappedTokenGatewayV3 _wrappedTokenGatewayV3) {
        i_lockPeriod = _lockPeriod;
        i_owner = msg.sender;
        i_aaveWrappedTokenGatewayV3 = _wrappedTokenGatewayV3;
    }

    ////////////////////
    // * External 	  //
    ////////////////////
    // can deposit multiple times
    // depositing starts new lock period counting for user
    function deposit() external payable {
        if (msg.value == 0) revert StrongHands__ZeroDeposit();

        _claimDividends();

        UserInfo storage user = users[msg.sender];
        user.balance += msg.value;
        user.lastDepositTimestamp = block.timestamp;

        totalStaked += msg.value;

        // AAVE_POOL argument is not important as WrappedTokenGatewayV3 will always use its own address and ignore this one, although this pool address is correct at this point of time
        i_aaveWrappedTokenGatewayV3.depositETH{value: msg.value}(AAVE_POOL, address(this), 0);
        emit Deposited(msg.sender, msg.value, block.timestamp);
    }

    // must withdraw all, can not withdraw partially
    // penalty goes from 50% at start to the 0% at the end of lock period
    function withdraw() external {
        UserInfo storage user = users[msg.sender];
        uint256 initialAmount = user.balance;
        if (initialAmount == 0) revert StrongHands__ZeroAmount();

        _claimDividends();

        uint256 penalty = calculatePenalty(msg.sender);

        user.balance = 0;
        totalStaked -= initialAmount;

        // totalStaked > 0 bcz cant divide by 0
        // disburse
        if (penalty > 0 && totalStaked > 0) {
            unclaimedDividends += penalty;
            // penalty / totalStaked -> How much penalty for each wei that is staked
            // * POINT_MULTIPLIER for precision
            totalDividendPoints += (penalty * POINT_MULTIPLIER) / totalStaked;
        }

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
    function _claimDividends() internal {
        UserInfo storage user = users[msg.sender];
        uint256 owing = _dividendsOwing(msg.sender);
        if (owing > 0) {
            unclaimedDividends -= owing;
            user.balance += owing;
        }
        user.lastDividendPoints = totalDividendPoints;
    }

    ////////////////////
    // * Private 	  //
    ////////////////////

    ////////////////////
    // * View & Pure  //
    ////////////////////

    // TODO -> Should this be public?
    // TODO -> Could save some gas by passing user.lastDepositTimestamp and user.balance ?
    function calculatePenalty(address user) public view returns (uint256) {
        uint256 unlockTimestamp = users[user].lastDepositTimestamp + i_lockPeriod;
        if (block.timestamp >= unlockTimestamp) return 0;

        uint256 timeLeft = unlockTimestamp - block.timestamp;

        // rewritten formula to minimize precision loss
        // users[user].balance * (timeLeft/i_lockPeriod) * (50/100)
        // ==
        // (users[user].balance * timeLeft * 50) / (i_lockPeriod * 100)
        // ==
        // (users[user].balance * timeLeft) / (i_lockPeriod * 2)
        return (users[user].balance * timeLeft) / (i_lockPeriod * 2);
    }

    function _dividendsOwing(address user) internal view returns (uint256) {
        // how many new points since this user last claimed
        uint256 newDividendPoints = totalDividendPoints - users[user].lastDividendPoints;
        return (users[user].balance * newDividendPoints) / POINT_MULTIPLIER;
    }
}
