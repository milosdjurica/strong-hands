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
    /// @notice Emitted when user claims dividends.
    /// @param user The address of the caller.
    /// @param amountClaimed The amount of dividends claimed by user.
    event ClaimedDividends(address indexed user, uint256 indexed amountClaimed);
    /// @notice Emitted when owner claims yield.
    /// @param owner The address of the owner.
    /// @param amount The amount of yield owner claimed.
    event ClaimedYield(address indexed owner, uint256 indexed amount);

    ////////////////////
    // * Structs 	  //
    ////////////////////
    /// @notice Stores individual user staking info
    /// @param balance The amount of ETH deposited by the user
    /// @param lastDepositTimestamp The timestamp of the user's last deposit
    /// @param lastDividendPoints Snapshot of dividend points when the user last updated. Update happens on every deposit, withdraw or when `claimDividends()` function is called directly
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
    /// Users can withdraw at any time, but penalties apply if they withdraw before this period ends.
    /// @dev Immutable variable
    uint256 public immutable i_lockPeriod;
    /// @notice Aave V3 WrappedTokenGatewayV3 contract for depositing and withdrawing ETH in the Aave V3 lending pool.
    /// @dev Aave V3 WrappedTokenGatewayV3 contract that wraps/unwraps raw ETH into/from WETH and deposits/withdraw into/from Aave V3 lending pool.
    /// @dev Immutable variable
    IWrappedTokenGatewayV3 public immutable i_wrappedTokenGatewayV3;
    /// @notice Aave V3 lending pool contract.
    /// @dev Immutable variable
    IPool public immutable i_pool;
    /// @notice aEthWETH token contract representing deposited ETH + yield.
    /// @dev Immutable variable
    IERC20 public immutable i_aEthWeth;

    ////////////////////
    // * State        //
    ////////////////////
    /// @notice Total amount of ETH (in wei) currently deposited and claimed dividends by all users in this contract.
    /// @dev Unclaimed dividends are not included in this total.
    /// @dev Sum of all user amounts `user.amount`
    uint256 public totalStaked;

    ///@notice Mapping of user addresses to their staking information.
    mapping(address => UserInfo) public users;
    /// @notice Cumulative dividend points used to track penalty distributions.
    uint256 public totalDividendPoints;
    /// @notice Sum of all penalties collected but not yet claimed by users.
    uint256 public unclaimedDividends;

    ////////////////////
    // * Constructor  //
    ////////////////////

    /**
     * @notice Initializes the StrongHands contract
     * @param _lockPeriod The lock duration in seconds
     * @param _wrappedTokenGatewayV3 Aave’s Wrapped Token Gateway address
     * @param _pool Aave V3 lending pool address
     * @param _aEthWeth The aEthWETH token contract used for yield tracking
     */
    constructor(uint256 _lockPeriod, IWrappedTokenGatewayV3 _wrappedTokenGatewayV3, IPool _pool, IERC20 _aEthWeth) {
        i_lockPeriod = _lockPeriod;
        i_wrappedTokenGatewayV3 = _wrappedTokenGatewayV3;
        i_pool = _pool;
        i_aEthWeth = _aEthWeth;
    }

    ////////////////////
    // * External 	  //
    ////////////////////
    /**
     * @notice Updates user info and stakes ETH into the contract, starting or restarting the lock period for user.
     * Claims any unclaimed dividends that belong to the caller beforehand.
     * @dev Reverts `StrongHands__ZeroDeposit()` if `msg.value == 0`.
     * @dev Wraps ETH and deposit into the Aave pool via `i_wrappedTokenGatewayV3`.
     * @dev Emits a {Deposited} event.
     */
    function deposit() external payable {
        if (msg.value == 0) revert StrongHands__ZeroDeposit();
        claimDividends();

        UserInfo storage user = users[msg.sender];
        user.balance += msg.value;
        user.lastDepositTimestamp = block.timestamp;
        totalStaked += msg.value;

        i_wrappedTokenGatewayV3.depositETH{value: msg.value}(address(i_pool), address(this), 0);
        emit Deposited(msg.sender, msg.value, block.timestamp);
    }

    /**
     * @notice Withdraw entire stake. Applies penalty if lock period not passed.
     * The penalty starts at 50% and gradually decreases to 0% as the lock period expires.
     * Claims any unclaimed dividends that belong to the caller beforehand.
     * @dev Partial withdrawals are not allowed. Calculates and distributes penalty to remaining stakers.
     * @dev Reverts `StrongHands__ZeroAmount()` if user has nothing to withdraw.
     * @dev Unwraps aEthWETH and sends ETH to the user via `i_wrappedTokenGatewayV3`.
     * @dev If the caller is the last active staker, their penalty remains in the contract forever (as there is no one to collect it) and accrues yield for the owner.
     * @dev Emits a {Withdrawn} event.
     */
    function withdraw() external {
        claimDividends();
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
    /**
     * @notice Allows the contract owner to claim protocol-generated yield (interest).
     * @param amount The amount of yield (in wei) to withdraw. Must be greater than 0 and less than available yield.
     * @dev Only owner of the contract can call this function.
     * @dev Reverts if the caller is not the owner of the contract.
     * @dev Reverts with `StrongHands__ZeroAmount()`.
     * @dev Reverts with `StrongHands__NotEnoughYield(amount, availableYield)` if amount exceeds available yield.
     */
    function claimYield(uint256 amount) external onlyOwner {
        if (amount == 0) revert StrongHands__ZeroAmount();

        uint256 balanceWithYield = i_aEthWeth.balanceOf(address(this));
        uint256 availableYield = balanceWithYield - totalStaked - unclaimedDividends;
        if (amount > availableYield) revert StrongHands__NotEnoughYield(amount, availableYield);

        i_aEthWeth.approve(address(i_wrappedTokenGatewayV3), amount);
        i_wrappedTokenGatewayV3.withdrawETH(address(i_pool), amount, msg.sender);

        emit ClaimedYield(msg.sender, amount);
    }

    ////////////////////
    // * Public 	  //
    ////////////////////
    /**
     * @notice Claims unclaimed dividends (redistributed penalties) for the caller.
     * @dev Called automatically on deposit/withdraw.
     */
    function claimDividends() public {
        UserInfo storage user = users[msg.sender];
        uint256 owing = _dividendsOwing(user);
        if (owing > 0) {
            unclaimedDividends -= owing;
            user.balance += owing;
            totalStaked += owing;
        }
        // This is updated every time, because we want to update user when he enters first time too
        user.lastDividendPoints = totalDividendPoints;
        emit ClaimedDividends(msg.sender, owing);
    }

    ////////////////////
    // * View & Pure  //
    ////////////////////
    /**
     * @notice Calculates the current penalty for a user's withdrawal.
     * @param user The address of the user.
     * @return The penalty amount to be redistributed to other active users.
     */
    function calculatePenalty(address user) public view returns (uint256) {
        // TODO -> Make it internal?
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

    /**
     * @notice Internal helper to calculate pending dividends for a user.
     * @param user The user's info struct.
     * @return Amount of dividends owed to the user.
     */
    function _dividendsOwing(UserInfo memory user) internal view returns (uint256) {
        // how many new points since this user last claimed
        uint256 newDividendPoints = totalDividendPoints - user.lastDividendPoints;
        return (user.balance * newDividendPoints) / POINT_MULTIPLIER;
    }
}
