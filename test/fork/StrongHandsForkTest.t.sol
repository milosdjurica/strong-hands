// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Test, console} from "forge-std/Test.sol";
import {StrongHands, Ownable} from "../../src/StrongHands.sol";
import {StrongHandsDeploy} from "../../script/StrongHandsDeploy.s.sol";
import {SetupTestsTest} from "../SetupTests.sol";

contract ReentrancyAttacker {
    StrongHands public target;
    bool public reentered;

    constructor(address _target) payable {
        target = StrongHands(_target);
    }

    function attack() external {
        target.deposit{value: address(this).balance}();
        target.withdraw();
    }

    receive() external payable {
        if (!reentered) {
            reentered = true;
            target.withdraw();
        }
    }
}

contract ForkTest is SetupTestsTest {
    ////////////////////////////////
    // * constructor() test       //
    ////////////////////////////////
    function testFork_constructor() public view skipWhenNotForking {
        if (block.chainid == 11155111) {
            assertEq(strongHands.i_lockPeriod(), LOCK_PERIOD);
            assertEq(strongHands.owner(), msg.sender);
            assertEq(address(strongHands.i_wrappedTokenGatewayV3()), address(deployScript.WRAPPED_TOKEN_GATEWAY_V3()));
            assertEq(address(strongHands.i_pool()), address(deployScript.POOL()));
            // assertEq(address(strongHands.i_WETH()), address(deployScript.WETH()));
            assertEq(address(strongHands.i_aEthWeth()), address(deployScript.A_WETH()));
        } else if (block.chainid == 1) {
            assertEq(strongHands.i_lockPeriod(), LOCK_PERIOD);
            assertEq(strongHands.owner(), msg.sender);
            assertEq(
                address(strongHands.i_wrappedTokenGatewayV3()), address(deployScript.WRAPPED_TOKEN_GATEWAY_V3_MAINNET())
            );
            assertEq(address(strongHands.i_pool()), address(deployScript.POOL_MAINNET()));
            // assertEq(address(strongHands.i_WETH()), address(deployScript.WETH_MAINNET()));
            assertEq(address(strongHands.i_aEthWeth()), address(deployScript.A_WETH_MAINNET()));
        }
    }

    ////////////////////////////////
    // * deposit() tests          //
    ////////////////////////////////
    function testFork_deposit_RevertIf_DepositIsZero() public skipWhenNotForking {
        vm.expectRevert(abi.encodeWithSelector(StrongHands.StrongHands__ZeroDeposit.selector));
        strongHands.deposit();
    }

    function testFork_deposit() public skipWhenNotForking {
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Deposited(BOB, 1 ether, block.timestamp);
        strongHands.deposit{value: 1 ether}();

        (uint256 balance,, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);

        assertEq(balance, 1 ether);
        assertEq(timestamp, block.timestamp);
        assertEq(strongHands.totalDividendPoints(), lastDividendPoints);
        assertEq(strongHands.totalDividendPoints(), 0);
        assertEq(strongHands.totalStaked(), 1 ether);

        // StrongHands contract should hold no raw ETH
        // TODO -> This check passes on mainnet, but fails on sepolia? Different ABIs probably because aave-v3-origin vs core & periphery
        // assertEq(address(strongHands).balance, 0);

        assertEq(strongHands.i_aEthWeth().balanceOf(address(strongHands)), 1 ether);
    }

    ////////////////////////////////
    // * withdraw() tests         //
    ////////////////////////////////
    function testFork_withdraw_Reentrancy() public skipWhenNotForking {
        vm.deal(address(this), 1 ether);
        ReentrancyAttacker attacker = new ReentrancyAttacker{value: 1 ether}(address(strongHands));

        vm.expectRevert();
        attacker.attack();

        // ! Checks
        (uint256 balance, uint256 claimedDividends, uint256 timestamp, uint256 lastDividendPoints) =
            strongHands.users(address(attacker));
        assertEq(balance, 0 ether);
        assertEq(claimedDividends, 0);
        assertEq(timestamp, 0);
        assertEq(strongHands.totalDividendPoints(), lastDividendPoints);
        assertEq(strongHands.totalDividendPoints(), 0);
        assertEq(strongHands.totalStaked(), 0 ether);
    }

    function testFork_withdraw_RevertIf_ZeroAmount() public skipWhenNotForking {
        vm.expectRevert(abi.encodeWithSelector(StrongHands.StrongHands__ZeroAmount.selector));
        strongHands.withdraw();
    }

    function testFork_withdraw_ZeroPenalty() public skipWhenNotForking depositWith(BOB, 1 ether) {
        assertEq(BOB.balance, 99 ether);

        skip(LOCK_PERIOD);
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, 1 ether, 0, block.timestamp);
        strongHands.withdraw();

        (uint256 balance,, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);
        // ! Checks
        assertEq(balance, 0);
        assertEq(timestamp, block.timestamp - LOCK_PERIOD);
        assertEq(lastDividendPoints, 0);
        assertEq(strongHands.totalStaked(), 0);
        assertEq(strongHands.totalDividendPoints(), 0);
        assertEq(BOB.balance, 100 ether);
        // owner still has aEthWeth acquired from the BOB deposit
        assertGt(strongHands.i_aEthWeth().balanceOf(address(strongHands)), 0);

        uint256 balanceBefore = msg.sender.balance;
        vm.prank(msg.sender);
        vm.expectEmit(true, true, true, true);
        emit ClaimedYield(msg.sender, 10);
        strongHands.claimYield(10);
        uint256 balanceAfter = msg.sender.balance;
        assertEq(balanceAfter - 10, balanceBefore);
    }

    function testFork_withdraw_MaxPenalty() public skipWhenNotForking depositWith(BOB, 1 ether) {
        // Bob deposited and instantly withdraws
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, 0.5 ether, 0.5 ether, block.timestamp);
        strongHands.withdraw();

        // ! Check StrongHands

        uint256 aEthWethBeforeSkip = strongHands.i_aEthWeth().balanceOf(address(strongHands));
        assertApproxEqRel(aEthWethBeforeSkip, 0.5 ether, 2);
        // assertEq(aEthWethBeforeSkip, 0.5 ether);
        assertEq(strongHands.totalStaked(), 0);
        // totalDividendPoints would normally be 0.5, but in this case will be 0 because there is no other active users, so nobody can get those dividends
        assertEq(strongHands.totalDividendPoints(), 0 ether);

        // ! Check Bob
        (uint256 balance,, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);
        assertEq(BOB.balance, 99.5 ether);
        assertEq(balance, 0);
        assertEq(timestamp, block.timestamp);
        assertEq(lastDividendPoints, 0);

        skip(1111);
        // StrongHands contracts keeps acquiring yield on aEthWeth until it is pulled out
        assertGt(strongHands.i_aEthWeth().balanceOf(address(strongHands)), aEthWethBeforeSkip);
    }

    // ! Note -> This test will work properly only if LOCK_PERIOD % 2 == 0
    function testFork_withdraw_MidPenalty() public skipWhenNotForking depositWith(BOB, 1 ether) {
        skip(LOCK_PERIOD / 2);
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, 0.75 ether, 0.25 ether, block.timestamp);
        strongHands.withdraw();

        // ! Bob Checks
        (uint256 balance,, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);
        assertEq(BOB.balance, 99.75 ether);
        assertEq(balance, 0);
        assertEq(timestamp, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPoints, 0);

        // ! Strong Hands Checks
        assertEq(strongHands.totalStaked(), 0);
        // totalDividendPoints would normally be 0.5, but in this case will be 0 because there is no other active users, so nobody can get those dividends
        assertEq(strongHands.totalDividendPoints(), 0 ether);
        uint256 aEthWethBalanceBeforeSkip = strongHands.i_aEthWeth().balanceOf(address(strongHands));
        assertGt(aEthWethBalanceBeforeSkip, 0.25 ether);

        skip(1111);
        // StrongHands contracts keeps acquiring yield on aEthWeth until it is pulled out
        uint256 aEthWethBalanceAfterTimePassed = strongHands.i_aEthWeth().balanceOf(address(strongHands));
        assertGt(aEthWethBalanceAfterTimePassed, aEthWethBalanceBeforeSkip);
    }

    ////////////////////////////////
    // * collectYield() tests     //
    ////////////////////////////////
    function testFork_collectYield_RevertIf_NotOwner() public depositWith(BOB, 1 ether) skipWhenNotForking {
        vm.expectRevert("Ownable: caller is not the owner");
        strongHands.claimYield(1);
    }

    function testFork_collectYield_RevertIf_ZeroAmount() public depositWith(BOB, 1 ether) skipWhenNotForking {
        vm.prank(msg.sender);
        vm.expectRevert(abi.encodeWithSelector(StrongHands.StrongHands__ZeroAmount.selector));
        strongHands.claimYield(0);
    }

    function testFork_collectYield_RevertIf_NotEnoughYield() public depositWith(BOB, 1 ether) skipWhenNotForking {
        vm.prank(msg.sender);
        vm.expectRevert(abi.encodeWithSelector(StrongHands.StrongHands__NotEnoughYield.selector, 1, 0));
        strongHands.claimYield(1);
    }

    function testFork_collectYield() public depositWith(BOB, 1 ether) depositWith(ALICE, 1 ether) skipWhenNotForking {
        skip(LOCK_PERIOD);
        uint256 balanceWithYield = strongHands.i_aEthWeth().balanceOf(address(strongHands));
        vm.prank(msg.sender);
        vm.expectEmit(true, true, true, true);
        emit ClaimedYield(msg.sender, 0.01 ether);
        strongHands.claimYield(1e16);
        uint256 balanceWithYieldAfter = strongHands.i_aEthWeth().balanceOf(address(strongHands));

        assertEq(balanceWithYieldAfter + 1e16, balanceWithYield);
    }

    ////////////////////////////////
    // * calculatePenalty() Tests //
    ////////////////////////////////
    function testFork_calculatePenalty() public depositWith(BOB, 1 ether) skipWhenNotForking {
        uint256 penalty = strongHands.calculatePenalty(BOB);
        assertEq(penalty, 0.5 ether);

        skip(LOCK_PERIOD / 2);
        penalty = strongHands.calculatePenalty(BOB);
        assertEq(penalty, 0.25 ether);

        skip(LOCK_PERIOD / 4);
        penalty = strongHands.calculatePenalty(BOB);
        assertEq(penalty, 0.125 ether);

        skip(LOCK_PERIOD);
        penalty = strongHands.calculatePenalty(BOB);
        assertEq(penalty, 0);
    }

    // Bob enters with 1 eth
    // Alice enters with 1 eth
    // Alice gets out immediately and pays 0.5 eth penalty
    // Bob withdraw without penalty and collects 0.5 reward from Alice's penalty
    function testFork_BobCollectsRewardFromAlice()
        public
        skipWhenNotForking
        depositWith(BOB, 1 ether)
        depositWith(ALICE, 1 ether)
    {
        assertEq(strongHands.totalStaked(), 2 ether);
        // ! ALICE WITHDRAWS INSTANTLY
        vm.prank(ALICE);
        strongHands.withdraw();

        // ! Checks Alice
        (uint256 balance,, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(ALICE);
        assertEq(ALICE.balance, 99.5 ether);
        assertEq(balance, 0);
        assertEq(timestamp, block.timestamp);
        assertEq(lastDividendPoints, 0);
        assertEq(strongHands.totalStaked(), 1 ether);

        // ! Checks Bob
        (uint256 balanceBob,, uint256 timestampBob, uint256 lastDividendPointsBob) = strongHands.users(BOB);
        assertEq(BOB.balance, 99 ether);
        assertEq(balanceBob, 1 ether); // not updated because Bob needs to withdraw or deposit to get updated
        assertEq(timestampBob, block.timestamp);
        assertEq(lastDividendPointsBob, 0); // not updated because Bob needs to withdraw or deposit to get updated

        // ! Checks StrongHands
        assertEq(strongHands.totalStaked(), 1 ether);
        assertEq(strongHands.totalDividendPoints(), 0.5 ether);
        assertEq(strongHands.unclaimedDividends(), 0.5 ether);
        uint256 aEthWethBalance = strongHands.i_aEthWeth().balanceOf(address(strongHands));
        assertApproxEqRel(aEthWethBalance, 1.5 ether, 1);

        // ! Checks to see if aEthWeth balance is growing
        skip(LOCK_PERIOD);
        // StrongHands contracts keeps acquiring yield on aEthWeth until it is pulled out
        uint256 aEthWethBalanceAfterTimePassed = strongHands.i_aEthWeth().balanceOf(address(strongHands));
        assertGt(aEthWethBalanceAfterTimePassed, aEthWethBalance);

        // ! BOB GETS OUT AND EARNS AWARD FROM ALICE
        vm.prank(BOB);
        strongHands.withdraw();

        // ! Checks
        (
            uint256 balanceBobAfterWithdraw,
            ,
            uint256 timestampBobAfterWithdraw,
            uint256 lastDividendPointsBobAfterWithdraw
        ) = strongHands.users(BOB);
        assertEq(BOB.balance, 100.5 ether);
        assertEq(balanceBobAfterWithdraw, 0);
        assertEq(timestampBobAfterWithdraw, block.timestamp - LOCK_PERIOD);
        assertEq(lastDividendPointsBobAfterWithdraw, 0.5e18);
        assertEq(strongHands.totalStaked(), 0);
    }

    // ! -> Alice, Bob, Charlie and Mark test. Second question from email
    function testFork_Alice_Bob_Active_Charlie_MidPenalty_Mark_MidPenalty()
        public
        skipWhenNotForking
        depositWith(BOB, 1 ether)
        depositWith(ALICE, 3 ether)
        depositWith(CHARLIE, 24 ether)
    {
        // ! Skip half of LOCK_PERIOD so Charlie pays 25% penalty
        skip(LOCK_PERIOD / 2);
        // ! Mark enters before Charlie exits, so he is eligible to get prize
        vm.prank(MARK);
        strongHands.deposit{value: 2 ether}();
        // ! Charlie withdraws
        vm.prank(CHARLIE);
        strongHands.withdraw();

        // ! Check Charlie
        (uint256 balanceCharlie,, uint256 timestampCharlie, uint256 lastDividendPointsCharlie) =
            strongHands.users(CHARLIE);
        assertEq(CHARLIE.balance, 94 ether);
        assertEq(balanceCharlie, 0 ether); // he withdrew
        assertEq(timestampCharlie, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPointsCharlie, 0);
        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 6 ether);
        assertEq(strongHands.unclaimedDividends(), 6 ether);
        assertEq(strongHands.totalDividendPoints(), 1 ether);

        // ! Mark withdraws and pays 25% penalty because we skip half of LOCK_PERIOD
        skip(LOCK_PERIOD / 2);
        vm.prank(MARK);
        strongHands.withdraw();

        // ! Check Mark
        (uint256 balanceMark,, uint256 timestampMark, uint256 lastDividendPointsMark) = strongHands.users(MARK);
        // 100 - 2 deposited + 2 prize - 0.5 ether penalty (25% of 2 deposited) => 3.5 to withdraw == 101.5 ether
        assertEq(MARK.balance, 101.5 ether);
        assertEq(balanceMark, 0 ether); // he withdrew
        assertEq(timestampMark, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPointsMark, 1 ether); // this is 1 ether - For 1 ether holding, you win 1 ether. He holds 2 ether -> Wins 2 ether
        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 4 ether);
        assertEq(strongHands.unclaimedDividends(), 4.5 ether); // 6 from Charlie + 0.5 from Mark but Mark picked up 2 ethers reward from Charlie
        assertEq(strongHands.totalDividendPoints(), 1.125 ether); // 1 from Charlie and 0.5/4 from mark = 1.125

        // ! Check Alice - BEFORE WITHDRAWING FROM HER ACC
        (uint256 balanceAlice,, uint256 timestampAlice, uint256 lastDividendPointsAlice) = strongHands.users(ALICE);
        assertEq(ALICE.balance, 97 ether);
        assertEq(balanceAlice, 3 ether); // not updated because Alice didnt call claimDividends
        assertEq(timestampAlice, block.timestamp - LOCK_PERIOD);
        assertEq(lastDividendPointsAlice, 0); // not updated because Alice didnt call claimDividends

        // ! Check Bob - BEFORE WITHDRAWING FROM HIS ACC
        (uint256 balanceBob,, uint256 timestampBob, uint256 lastDividendPointsBob) = strongHands.users(BOB);
        assertEq(BOB.balance, 99 ether);
        assertEq(balanceBob, 1 ether); // not updated because Bob didnt call claimDividends
        assertEq(timestampBob, block.timestamp - LOCK_PERIOD);
        assertEq(lastDividendPointsBob, 0); // this is 1 ether - For 1 ether holding, you win 1 ether. He holds 2 ether -> Wins 2 ether prize

        // ! Alice Withdraws
        vm.prank(ALICE);
        strongHands.withdraw();

        // ! Check Alice - AFTER WITHDRAWING FROM HER ACC
        (uint256 balanceAliceAfter,, uint256 timestampAliceAfter, uint256 lastDividendPointsAliceAfter) =
            strongHands.users(ALICE);
        // 100 - 3 deposited + 3 from Charlie + 3 withdrawn + (0.5/4*3) => 0.375 from Mark
        assertEq(ALICE.balance, 103.375 ether);
        assertEq(balanceAliceAfter, 0); // withdrew
        assertEq(timestampAliceAfter, block.timestamp - LOCK_PERIOD);
        assertEq(lastDividendPointsAliceAfter, 1.125 ether); // this is 1 ether from Charlie + 0.125 from Mark - For 1 ether holding, you win 1.125 ether. She holds 3 ether -> Wins 3.375 ether prize
        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 1 ether);
        assertEq(strongHands.unclaimedDividends(), 1.125 ether); // 6 from Charlie and 0.5 from Mark but Mark picked up 2 ethers reward from Charlie and Alice picked up 3 ethers reward from Charlie and 0.375 from Mark
        assertEq(strongHands.totalDividendPoints(), 1.125 ether);

        // ! Bob Withdraws
        vm.prank(BOB);
        strongHands.withdraw();

        // ! Check Bob - AFTER WITHDRAWING FROM HIS ACC
        (uint256 balanceBobAfter,, uint256 timestampBobAfter, uint256 lastDividendPointsBobAfter) =
            strongHands.users(BOB);
        // 100 - 1 deposited + 1 from Charlie + 1 withdrawn + 0.125 from Mark
        assertEq(BOB.balance, 101.125 ether);
        assertEq(balanceBobAfter, 0); // withdrew
        assertEq(timestampBobAfter, block.timestamp - LOCK_PERIOD);
        assertEq(lastDividendPointsBobAfter, 1.125 ether); // this is 1 ether from Charlie + 0.25 from Mark - For 1 ether holding, you win 1.25 ether. He holds 1 ether -> Wins 1.25 ether prize

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 0);
        assertEq(strongHands.unclaimedDividends(), 0); // 6 from Charlie and 0.5 from Mark. Mark picked up 2 ethers reward from Charlie. Alice picked up 3 ethers reward from Charlie and 0.375 from Mark. Bob picked up 1 ethers reward from Charlie and 0.125 from Mark === 6 + 0.5 - 2 - 3 - 0.375 - 1 - 0.125
        assertEq(strongHands.totalDividendPoints(), 1.125 ether); // this is 1 ether from Charlie + 0.25 from Mark - For 1 ether holding, you win 1.25 ether. He holds 1 ether -> Wins 1.25 ether prize
    }

    // ! -> Alice, Bob, Charlie, Mark and Jane test. First question from email.
    function testFork_Alice_Bob_Active_Charlie_MidPenalty_JaneEnters_TakesHalfOfNextPenalty()
        public
        skipWhenNotForking
        depositWith(BOB, 1 ether)
        depositWith(ALICE, 3 ether)
        depositWith(CHARLIE, 24 ether)
        depositWith(MARK, 2 ether)
    {
        _janeTestSetup();

        // ! Jane deposits
        vm.prank(JANE);
        strongHands.deposit{value: 6 ether}();

        // ! Checks Alice
        (uint256 balanceAlice, uint256 claimedDividendsAlice, uint256 timestampAlice, uint256 lastDividendPointsAlice) =
            strongHands.users(ALICE);
        assertEq(ALICE.balance, 97 ether);
        assertEq(balanceAlice, 3 ether);
        assertEq(claimedDividendsAlice, 0 ether); // didn't claim
        assertEq(timestampAlice, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPointsAlice, 0 ether); // didn't claim
        (uint256 balanceBob, uint256 claimedDividendsBob, uint256 timestampBob, uint256 lastDividendPointsBob) =
            strongHands.users(BOB);

        // ! Checks Bob
        assertEq(BOB.balance, 99 ether);
        assertEq(balanceBob, 1 ether);
        assertEq(claimedDividendsBob, 0 ether); // didn't claim
        assertEq(timestampBob, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPointsBob, 0 ether); // didn't claim
        (uint256 balanceMark, uint256 claimedDividendsMark, uint256 timestampMark, uint256 lastDividendPointsMark) =
            strongHands.users(MARK);

        // ! Checks Mark
        assertEq(MARK.balance, 98 ether);
        assertEq(balanceMark, 2 ether);
        assertEq(claimedDividendsMark, 0 ether); // didn't claim
        assertEq(timestampMark, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPointsMark, 0 ether); // didn't claim

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 12 ether);
        assertEq(strongHands.unclaimedDividends(), 6 ether);
        assertEq(strongHands.totalDividendPoints(), 1 ether);

        // ! Mia deposits and withdraws immediately -> Pays penalty 50% == 18 ether
        vm.startPrank(MIA);
        strongHands.deposit{value: 36 ether}();
        strongHands.withdraw();
        vm.stopPrank();

        // ! Jane withdraws after her LOCK_TIME has passed (no penalty)
        skip(LOCK_PERIOD);
        vm.prank(JANE);
        strongHands.withdraw();
        // ! Checks Jane
        (uint256 balanceJane,, uint256 timestampJane, uint256 lastDividendPointsJane) = strongHands.users(JANE);
        assertEq(JANE.balance, 109 ether);
        assertEq(balanceJane, 0 ether); // withdrew
        assertEq(timestampJane, block.timestamp - LOCK_PERIOD);
        assertEq(lastDividendPointsJane, 2.5 ether); // 1 + 1.5 from Mia

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 6 ether); // Alice + Bob + Mark
        assertEq(strongHands.unclaimedDividends(), 15 ether); // 6 + 9 from Mia
        assertEq(strongHands.totalDividendPoints(), 2.5 ether); // 1 + 1.5 from Mia
    }

    // ! -> Alice, Bob, Charlie, Mark and Jane test. First question from email.
    function testFork_Alice_Bob_Active_Charlie_MidPenalty_JaneEnters_TakesThirdOfNextPenalty()
        public
        skipWhenNotForking
        depositWith(BOB, 1 ether)
        depositWith(ALICE, 3 ether)
        depositWith(CHARLIE, 24 ether)
        depositWith(MARK, 2 ether)
    {
        _janeTestSetup();

        // ! Jane deposits
        vm.prank(JANE);
        strongHands.deposit{value: 6 ether}();

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 12 ether);
        assertEq(strongHands.unclaimedDividends(), 6 ether);
        assertEq(strongHands.totalDividendPoints(), 1 ether);

        // ! Alice, Bob and Mark claim
        vm.prank(ALICE);
        strongHands.claimDividends();
        vm.prank(BOB);
        strongHands.claimDividends();
        vm.prank(MARK);
        strongHands.claimDividends();

        (uint256 balanceAlice, uint256 claimedDividendsAlice, uint256 timestampAlice, uint256 lastDividendPointsAlice) =
            strongHands.users(ALICE);
        // ! Checks Alice
        assertEq(ALICE.balance, 97 ether);
        assertEq(balanceAlice, 3 ether);
        assertEq(claimedDividendsAlice, 3 ether);
        assertEq(timestampAlice, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPointsAlice, 1 ether);
        (uint256 balanceBob, uint256 claimedDividendsBob, uint256 timestampBob, uint256 lastDividendPointsBob) =
            strongHands.users(BOB);

        // ! Checks Bob
        assertEq(BOB.balance, 99 ether);
        assertEq(balanceBob, 1 ether);
        assertEq(claimedDividendsBob, 1 ether);
        assertEq(timestampBob, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPointsBob, 1 ether);
        (uint256 balanceMark, uint256 claimedDividendsMark, uint256 timestampMark, uint256 lastDividendPointsMark) =
            strongHands.users(MARK);

        // ! Checks Mark
        assertEq(MARK.balance, 98 ether);
        assertEq(balanceMark, 2 ether);
        assertEq(claimedDividendsMark, 2 ether);
        assertEq(timestampMark, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPointsMark, 1 ether);

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 18 ether);
        assertEq(strongHands.unclaimedDividends(), 0 ether);
        assertEq(strongHands.totalDividendPoints(), 1 ether);

        // ! Mia deposits and withdraws immediately -> Pays penalty 50% == 18 ether
        vm.startPrank(MIA);
        strongHands.deposit{value: 36 ether}();
        strongHands.withdraw();
        vm.stopPrank();

        // ! Jane withdraws after her LOCK_TIME has passed (no penalty)
        skip(LOCK_PERIOD);
        vm.prank(JANE);
        strongHands.withdraw();
        // ! Checks Jane
        (uint256 balanceJane, uint256 claimedDividendsJane, uint256 timestampJane, uint256 lastDividendPointsJane) =
            strongHands.users(JANE);
        assertEq(JANE.balance, 106 ether);
        assertEq(balanceJane, 0 ether); // withdrew
        assertEq(claimedDividendsJane, 0 ether); // withdrew
        assertEq(timestampJane, block.timestamp - LOCK_PERIOD);
        assertEq(lastDividendPointsJane, 2 ether); // 1 before + 1 from Mia

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 12 ether); // Alice + Bob + Mark
        assertEq(strongHands.unclaimedDividends(), 12 ether); // 18 from Mia - 6 that Jane claimed
        assertEq(strongHands.totalDividendPoints(), 2 ether); // 1 before + 1 from Mia
    }

    // ! INTERNAL/HELPER FUNCTION
    function _janeTestSetup() internal {
        skip(LOCK_PERIOD / 2);
        // ! Charlie withdraws
        vm.prank(CHARLIE);
        strongHands.withdraw();

        // ! Check Charlie
        (uint256 balanceCharlie,, uint256 timestampCharlie, uint256 lastDividendPointsCharlie) =
            strongHands.users(CHARLIE);
        assertEq(CHARLIE.balance, 94 ether);
        assertEq(balanceCharlie, 0 ether); // he withdrew
        assertEq(timestampCharlie, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPointsCharlie, 0);

        // ! Check Mark
        (uint256 balanceMark,, uint256 timestampMark, uint256 lastDividendPointsMark) = strongHands.users(MARK);
        assertEq(MARK.balance, 98 ether);
        assertEq(balanceMark, 2 ether); // not updated because Mark didnt call claimDividends
        assertEq(timestampMark, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPointsMark, 0); // not updated because Mark didnt call claimDividends

        // ! Check Alice
        (uint256 balanceAlice,, uint256 timestampAlice, uint256 lastDividendPointsAlice) = strongHands.users(ALICE);
        assertEq(ALICE.balance, 97 ether);
        assertEq(balanceAlice, 3 ether); // not updated because Alice didnt call claimDividends
        assertEq(timestampAlice, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPointsAlice, 0); // not updated because Alice didnt call claimDividends

        // ! Check Bob
        (uint256 balanceBob,, uint256 timestampBob, uint256 lastDividendPointsBob) = strongHands.users(BOB);
        assertEq(BOB.balance, 99 ether);
        assertEq(balanceBob, 1 ether); // not updated because Bob didnt call claimDividends
        assertEq(timestampBob, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPointsBob, 0); // not updated because Bob didnt call claimDividends

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 6 ether);
        assertEq(strongHands.unclaimedDividends(), 6 ether);
        assertEq(strongHands.totalDividendPoints(), 1 ether);
    }

    function testFork_withdraw_NoOneToCollectReward() public skipWhenNotForking depositWith(BOB, 1 ether) {
        vm.prank(BOB);
        strongHands.withdraw();

        // ! Check Bob
        (uint256 balance,, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);
        assertEq(balance, 0 ether);
        assertEq(timestamp, block.timestamp);
        assertEq(lastDividendPoints, 0);

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 0);
        assertEq(strongHands.unclaimedDividends(), 0 ether);
        assertEq(strongHands.totalDividendPoints(), 0);

        skip(LOCK_PERIOD);
        // ! Owner can claim 0.5 penalty from Bob and yield from it
        vm.prank(msg.sender);
        strongHands.claimYield(0.5 ether);

        // ! Alice enters
        vm.prank(ALICE);
        strongHands.deposit{value: 1 ether}();

        // ! Check Alice
        (uint256 balanceAlice, uint256 claimedDividendsAlice, uint256 timestampAlice, uint256 lastDividendPointsAlice) =
            strongHands.users(ALICE);
        assertEq(balanceAlice, 1 ether);
        assertEq(claimedDividendsAlice, 0);
        assertEq(timestampAlice, block.timestamp);
        assertEq(lastDividendPointsAlice, 0);

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 1 ether);
        assertEq(strongHands.unclaimedDividends(), 0);
        assertEq(strongHands.totalDividendPoints(), 0);

        // ! Alice withdraws after time passed
        skip(LOCK_PERIOD);
        vm.prank(ALICE);
        strongHands.withdraw();

        // ! Check Alice after withdraw
        (
            uint256 balanceAliceAfterWithdraw,
            uint256 claimedDividendsAliceAfterWithdraw,
            uint256 timestampAliceAfterWithdraw,
            uint256 lastDividendPointsAliceAfterWithdraw
        ) = strongHands.users(ALICE);
        assertEq(balanceAliceAfterWithdraw, 0);
        assertEq(claimedDividendsAliceAfterWithdraw, 0);
        assertEq(timestampAliceAfterWithdraw, block.timestamp - LOCK_PERIOD);
        assertEq(lastDividendPointsAliceAfterWithdraw, 0);

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 0);
        assertEq(strongHands.unclaimedDividends(), 0);
        assertEq(strongHands.totalDividendPoints(), 0);
    }
}
