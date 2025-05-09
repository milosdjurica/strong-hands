// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IWrappedTokenGatewayV3} from "@aave/v3-origin/contracts/helpers/interfaces/IWrappedTokenGatewayV3.sol";
import {Ownable} from "@aave/v3-origin/contracts/dependencies/openzeppelin/contracts/Ownable.sol";
import {IPool} from "@aave/v3-origin/contracts/interfaces/IPool.sol";
import {IWETH} from "@aave/v3-origin/contracts/helpers/interfaces/IWETH.sol";
import {IERC20} from "@aave/v3-origin/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

contract StrongHands is Ownable {
    ////////////////////
    // * Errors 	  //
    ////////////////////
    // error StrongHands__NotOwner(address msgSender, address owner);
    error StrongHands__ZeroDeposit();
    error StrongHands__ZeroAmount();

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
    uint256 public constant POINT_MULTIPLIER = 1e18;
    uint256 public constant PENALTY_START_PERCENT = 50;

    ////////////////////
    // * Immutables	  //
    ////////////////////
    // lock period duration (seconds)
    uint256 public immutable i_lockPeriod;
    IWrappedTokenGatewayV3 public immutable i_wrappedTokenGatewayV3;
    IPool public immutable i_pool;
    IWETH public immutable i_WETH;
    IERC20 public immutable i_aEthWeth;

    ////////////////////
    // * State        //
    ////////////////////
    // sum of all user.amount
    uint256 public totalStaked;
    // mapping of all users in the system
    mapping(address => UserInfo) public users;
    uint256 public totalDividendPoints;
    uint256 public unclaimedDividends;

    ////////////////////
    // * Modifiers 	  //
    ////////////////////
    modifier claimDividends() {
        UserInfo storage user = users[msg.sender];
        uint256 owing = _dividendsOwing(msg.sender);
        if (owing > 0) {
            unclaimedDividends -= owing;
            user.balance += owing;
            user.lastDividendPoints = totalDividendPoints;
            // ! IMPORTANT CHANGE !!!!!!!!!!!!!! Solution for distributing properly rewards
            totalStaked += owing;
        }
        _;
    }

    ////////////////////
    // * Constructor  //
    ////////////////////
    constructor(
        uint256 _lockPeriod,
        IWrappedTokenGatewayV3 _wrappedTokenGatewayV3,
        IPool _pool,
        IWETH _weth,
        IERC20 _aEthWeth
    ) {
        i_lockPeriod = _lockPeriod;
        i_wrappedTokenGatewayV3 = _wrappedTokenGatewayV3;
        i_pool = _pool;
        i_WETH = _weth;
        i_aEthWeth = _aEthWeth;
    }

    ////////////////////
    // * External 	  //
    ////////////////////
    // can deposit multiple times
    // depositing starts new lock period counting for user
    function deposit() external payable claimDividends {
        if (msg.value == 0) revert StrongHands__ZeroDeposit();

        UserInfo storage user = users[msg.sender];
        user.balance += msg.value;
        user.lastDepositTimestamp = block.timestamp;

        totalStaked += msg.value;

        // AAVE_POOL argument is not important as WrappedTokenGatewayV3 will always use its own address and ignore this one, although this pool address is correct at this point of time
        i_wrappedTokenGatewayV3.depositETH{value: msg.value}(address(i_pool), address(this), 0);
        emit Deposited(msg.sender, msg.value, block.timestamp);
    }

    // must withdraw all, can not withdraw partially
    // penalty goes from 50% at start to the 0% at the end of lock period
    function withdraw() external claimDividends {
        UserInfo storage user = users[msg.sender];
        uint256 initialAmount = user.balance;
        if (initialAmount == 0) revert StrongHands__ZeroAmount();

        uint256 penalty = calculatePenalty(msg.sender);

        user.balance = 0;
        uint256 payout = initialAmount - penalty;
        // TODO -> This stays the same but in modifier totalStaked is updated `totalStaked+reward` in order to redistribute properly
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

        // !  approving aEthWeth transfer before withdrawing
        i_aEthWeth.approve(address(i_wrappedTokenGatewayV3), payout);
        i_wrappedTokenGatewayV3.withdrawETH(address(i_pool), payout, msg.sender);

        emit Withdrawn(msg.sender, payout, penalty, block.timestamp);
    }

    ////////////////////
    // * Only Owner   //
    ////////////////////
    // ONLY OWNER can call this function. He can call it at any moment
    function claimInterest() external onlyOwner {
        // TODO -> finish this function !!!
        // TODO -> Important to note that user will never be able to pull out unclaimed dividends. Even if first used gets in and goes out and gets punished and there is no one to collect the prize, user also wont be able to do it. This amount would stay forever to keep acquiring the interest
    }

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
