// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IWrappedTokenGatewayV3} from "@aave/v3-origin/contracts/helpers/interfaces/IWrappedTokenGatewayV3.sol";
import {Ownable} from "@aave/v3-origin/contracts/dependencies/openzeppelin/contracts/Ownable.sol";
import {IPool} from "@aave/v3-origin/contracts/interfaces/IPool.sol";
import {IERC20} from "@aave/v3-origin/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

contract StrongHands is Ownable {
    ////////////////////
    // * Errors 	  //
    ////////////////////
    /// @notice Thrown when a user attempts to deposit 0 ETH.
    error StrongHands__ZeroDeposit();
    /// @notice Thrown when a user tries to withdraw with 0 balance or when owner tries to claim yield passing 0 amount as a parameter.
    error StrongHands__ZeroAmount();
    /// @notice Thrown when the owner tries to claim more yield than available.
    /// @param desiredAmount The amount the owner tried to withdraw.
    /// @param actualYield The actual available yield for withdrawal.
    error StrongHands__NotEnoughYield(uint256 desiredAmount, uint256 actualYield);

    ////////////////////
    // * Events 	  //
    ////////////////////

    /// @notice Emitted when a user deposits/stakes ETH.
    /// @param user The address of the depositor.
    /// @param amount The amount of ETH deposited.
    /// @param timestamp The timestamp of deposit.
    event Deposited(address indexed user, uint256 indexed amount, uint256 indexed timestamp);
    /// @notice Emitted when a user withdraws/unstake ETH.
    /// @param user The address of the withdrawer.
    /// @param payout The final amount user received (after penalty).
    /// @param penalty The penalty amount redistributed to other users. Will be 0 if user withdraws after his `i_lockPeriod` has passed.
    /// @param timestamp The timestamp of withdrawal.
    event Withdrawn(address indexed user, uint256 indexed payout, uint256 indexed penalty, uint256 timestamp);

    ////////////////////
    // * Structs 	  //
    ////////////////////
    /// @notice Stores individual user staking info
    /// @param balance The amount of ETH deposited by the user
    /// @param lastDepositTimestamp The timestamp of the user's last deposit
    /// @param lastDividendPoints Snapshot of dividend points when the user last updated. Update happens on every deposit, withdraw or when `claimRewards()` function is called directly
    struct UserInfo {
        uint256 balance;
        uint256 lastDepositTimestamp;
        uint256 lastDividendPoints;
    }

    ////////////////////
    // * Constants	  //
    ////////////////////
    /// @notice Precision multiplier for dividend point calculations.
    /// @dev Used to avoid loss of precision when distributing penalties as dividends.
    uint256 public constant POINT_MULTIPLIER = 1e18;

    ////////////////////
    // * Immutables	  //
    ////////////////////
    /// @notice Duration (in seconds) during which early withdrawals are subject to penalties.
    /// @notice Users can withdraw at any time, but penalties apply if they withdraw before this period ends.
    uint256 public immutable i_lockPeriod;
    /// @notice Aave V3 WrappedTokenGatewayV3 contract for depositing and withdrawing ETH in the Aave V3 lending pool.
    /// @dev Aave V3 WrappedTokenGatewayV3 contract that wraps/unwraps raw ETH into/from WETH and deposits/withdraw from Aave V3 lending pool.
    IWrappedTokenGatewayV3 public immutable i_wrappedTokenGatewayV3;
    /// @notice Aave V3 lending pool contract.
    IPool public immutable i_pool;
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

    ////////////////////
    // * Constructor  //
    ////////////////////
    constructor(uint256 _lockPeriod, IWrappedTokenGatewayV3 _wrappedTokenGatewayV3, IPool _pool, IERC20 _aEthWeth) {
        i_lockPeriod = _lockPeriod;
        i_wrappedTokenGatewayV3 = _wrappedTokenGatewayV3;
        i_pool = _pool;
        i_aEthWeth = _aEthWeth;
    }

    ////////////////////
    // * External 	  //
    ////////////////////
    // can deposit multiple times
    // depositing starts new lock period counting for user
    function deposit() external payable {
        claimRewards();
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
    function withdraw() external {
        claimRewards();
        UserInfo storage user = users[msg.sender];
        uint256 initialAmount = user.balance;
        if (initialAmount == 0) revert StrongHands__ZeroAmount();

        uint256 penalty = calculatePenalty(msg.sender);

        user.balance = 0;
        uint256 payout = initialAmount - penalty;
        // TODO -> This stays the same but in modifier totalStaked is updated `totalStaked+reward` in order to redistribute properly
        // Maybe move this after disburse???
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
    // could be changed to always withdraw full yield and user has no option to choose
    function claimYield(uint256 amount) external onlyOwner {
        if (amount == 0) revert StrongHands__ZeroAmount();
        uint256 balanceWithYield = i_aEthWeth.balanceOf(address(this));
        uint256 yield = balanceWithYield - totalStaked - unclaimedDividends;

        // This could be changed to give back full yield if amount is > yield
        if (amount > yield) revert StrongHands__NotEnoughYield(amount, yield);

        i_aEthWeth.approve(address(i_wrappedTokenGatewayV3), amount);
        i_wrappedTokenGatewayV3.withdrawETH(address(i_pool), amount, msg.sender);
    }

    ////////////////////
    // * Public 	  //
    ////////////////////
    // This function should be callable by users to claim rewards. Also automatically called when deposit/withdraw is called
    // PUBLIC !!!
    function claimRewards() public {
        UserInfo storage user = users[msg.sender];
        uint256 owing = _dividendsOwing(user);
        if (owing > 0) {
            unclaimedDividends -= owing;
            user.balance += owing;
            totalStaked += owing;
        }
        // This is updated every time, because we want to update user when he enters first time too
        user.lastDividendPoints = totalDividendPoints;
    }

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

    function _dividendsOwing(UserInfo memory user) internal view returns (uint256) {
        // how many new points since this user last claimed
        uint256 newDividendPoints = totalDividendPoints - user.lastDividendPoints;
        return (user.balance * newDividendPoints) / POINT_MULTIPLIER;
    }
}
