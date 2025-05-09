// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Test, console} from "forge-std/Test.sol";
import {StrongHands} from "../../src/StrongHands.sol";
import {StrongHandsDeploy} from "../../script/StrongHandsDeploy.s.sol";
import {SetupTestsTest} from "../SetupTests.sol";

contract ForkTest is SetupTestsTest {
    function testFork_constructor() public view skipWhenNotForking {
        if (block.chainid == 11155111) {
            assertEq(strongHands.i_lockPeriod(), LOCK_PERIOD);
            assertEq(strongHands.owner(), msg.sender);
            assertEq(address(strongHands.i_wrappedTokenGatewayV3()), address(deployScript.WRAPPED_TOKEN_GATEWAY_V3()));
            assertEq(address(strongHands.i_pool()), address(deployScript.POOL()));
            assertEq(address(strongHands.i_WETH()), address(deployScript.WETH()));
            assertEq(address(strongHands.i_aEthWeth()), address(deployScript.A_WETH()));
        } else {
            assertEq(strongHands.i_lockPeriod(), LOCK_PERIOD);
            assertEq(strongHands.owner(), msg.sender);
            assertEq(
                address(strongHands.i_wrappedTokenGatewayV3()), address(deployScript.WRAPPED_TOKEN_GATEWAY_V3_MAINNET())
            );
            assertEq(address(strongHands.i_pool()), address(deployScript.POOL_MAINNET()));
            assertEq(address(strongHands.i_WETH()), address(deployScript.WETH_MAINNET()));
            assertEq(address(strongHands.i_aEthWeth()), address(deployScript.A_WETH_MAINNET()));
        }
    }

    // ! Deposit tests
    function testFork_deposit_RevertIf_DepositIsZero() public skipWhenNotForking {
        vm.expectRevert(abi.encodeWithSelector(StrongHands.StrongHands__ZeroDeposit.selector));
        strongHands.deposit();
    }

    function testFork_deposit() public skipWhenNotForking {
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Deposited(BOB, 1 ether, block.timestamp);
        strongHands.deposit{value: 1 ether}();

        (uint256 balance, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);

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

    // ! Withdraw tests
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

        (uint256 balance, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);
        // ! Checks
        assertEq(balance, 0);
        assertEq(timestamp, block.timestamp - LOCK_PERIOD);
        assertEq(lastDividendPoints, 0);
        assertEq(strongHands.totalStaked(), 0);
        assertEq(strongHands.totalDividendPoints(), 0);
        assertEq(BOB.balance, 100 ether);
        // owner still has aEthWeth acquired from the BOB deposit
        assertGt(strongHands.i_aEthWeth().balanceOf(address(strongHands)), 0);

        // TODO -> check if owner can pull those tokens later, check if can pull something before too (if owner can choose how much he wants out)
        // uint256 balanceBefore = msg.sender.balance;
        // strongHands.claimInterest();
        // uint256 balanceAfter = msg.sender.balance;
        // assertGt(balanceAfter, balanceBefore);
    }

    function testFork_withdraw_MaxPenalty() public skipWhenNotForking depositWith(BOB, 1 ether) {
        // Bob deposited and instantly withdraws
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, 0.5 ether, 0.5 ether, block.timestamp);
        strongHands.withdraw();

        // ! StrongHands Checks
        uint256 aEthWethBeforeSkip = strongHands.i_aEthWeth().balanceOf(address(strongHands));
        assertEq(aEthWethBeforeSkip, 0.5 ether);
        assertEq(strongHands.totalStaked(), 0);
        // totalDividendPoints would normally be 0.5, but in this case will be 0 because there is no other active users, so nobody can get those dividends
        assertEq(strongHands.totalDividendPoints(), 0 ether);

        // ! Bob Checks
        (uint256 balance, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);
        assertEq(BOB.balance, 99.5 ether);
        assertEq(balance, 0);
        assertEq(timestamp, block.timestamp);
        assertEq(lastDividendPoints, 0);

        skip(1111);
        // StrongHands contracts keeps acquiring interest on aEthWeth until it is pulled out
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
        (uint256 balance, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);
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
        // StrongHands contracts keeps acquiring interest on aEthWeth until it is pulled out
        uint256 aEthWethBalanceAfterTimePassed = strongHands.i_aEthWeth().balanceOf(address(strongHands));
        assertGt(aEthWethBalanceAfterTimePassed, aEthWethBalanceBeforeSkip);
    }

    // Bob enters with 1 eth
    // Alice enters with 1 eth
    // Alice gets out immediately and pays 0.5 eth penalty
    // Bob withdraw without penalty and collects reward from Alice's penalty
    function testFork_totalSupplyCheck() public skipWhenNotForking depositWith(BOB, 1 ether) {
        skip(LOCK_PERIOD);
        // ! ALICE ENTERS AND WITHDRAWS INSTANTLY
        vm.prank(ALICE);
        strongHands.deposit{value: 1 ether}();
        assertEq(strongHands.totalStaked(), 2 ether);
        vm.prank(ALICE);
        strongHands.withdraw();

        // ! Checks Alice
        (uint256 balance, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(ALICE);
        assertEq(balance, 0);
        assertEq(timestamp, block.timestamp);
        assertEq(lastDividendPoints, 0);
        assertEq(strongHands.totalStaked(), 1 ether);

        // ! Checks Bob
        (uint256 balanceBob, uint256 timestampBob, uint256 lastDividendPointsBob) = strongHands.users(BOB);
        assertEq(balanceBob, 1 ether); // not updated because Bob needs to withdraw or deposit to get updated
        assertEq(timestampBob, block.timestamp - LOCK_PERIOD);
        assertEq(lastDividendPointsBob, 0); // not updated because Bob needs to withdraw or deposit to get updated
        assertEq(strongHands.totalStaked(), 1 ether);

        // ! Additional checks ->  totalDividendPoints(), balances, aEthWeth
        uint256 expectedTotalDividendPoints = 0.5 ether;
        assertEq(strongHands.totalDividendPoints(), expectedTotalDividendPoints);
        assertEq(ALICE.balance, 99.5 ether);
        assertEq(BOB.balance, 99 ether);
        uint256 aEthWethBalance = strongHands.i_aEthWeth().balanceOf(address(strongHands));
        assertGt(aEthWethBalance, 1.5 ether);

        // ! Checks to see if aEthWeth balance is growing
        skip(LOCK_PERIOD);
        // StrongHands contracts keeps acquiring interest on aEthWeth until it is pulled out
        uint256 aEthWethBalanceAfterTimePassed = strongHands.i_aEthWeth().balanceOf(address(strongHands));
        assertGt(aEthWethBalanceAfterTimePassed, aEthWethBalance);

        // ! BOB GETS OUT AND EARNS AWARD FROM ALICE
        vm.prank(BOB);
        strongHands.withdraw();

        // ! Checks
        (uint256 balanceBobAfterWithdraw, uint256 timestampBobAfterWithdraw, uint256 lastDividendPointsBobAfterWithdraw)
        = strongHands.users(BOB);
        assertEq(BOB.balance, 100.5 ether);
        assertEq(balanceBobAfterWithdraw, 0);
        assertEq(timestampBobAfterWithdraw, block.timestamp - 2 * LOCK_PERIOD);
        assertEq(lastDividendPointsBobAfterWithdraw, 0.5e18);
        assertEq(strongHands.totalStaked(), 0);
    }

    // TODO -> Alice, Bob, Charlie and Mark test. Second question from email
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
        (uint256 balanceCharlie, uint256 timestampCharlie, uint256 lastDividendPointsCharlie) =
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
        (uint256 balanceMark, uint256 timestampMark, uint256 lastDividendPointsMark) = strongHands.users(MARK);
        // 100 - 2 deposited + 2 prize - 1 ether penalty (25% of 2 deposited + 2 prize) + 3 withdrawn == 101 ether
        assertEq(MARK.balance, 101 ether);
        assertEq(balanceMark, 0 ether); // he withdrew
        assertEq(timestampMark, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPointsMark, 1 ether); // this is 1 ether - For 1 ether holding, you win 1 ether. He holds 2 ether -> Wins 2 ether
        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 4 ether);
        assertEq(strongHands.unclaimedDividends(), 5 ether); // 6 from Charlie + 1 from Mark but Mark picked up 2 ethers reward from Charlie
        assertEq(strongHands.totalDividendPoints(), 1.25 ether);

        // ! Check Alice - BEFORE WITHDRAWING FROM HER ACC
        (uint256 balanceAlice, uint256 timestampAlice, uint256 lastDividendPointsAlice) = strongHands.users(ALICE);
        assertEq(ALICE.balance, 97 ether);
        assertEq(balanceAlice, 3 ether); // not updated because Alice didnt call claimRewards
        assertEq(timestampAlice, block.timestamp - LOCK_PERIOD);
        assertEq(lastDividendPointsAlice, 0); // not updated because Alice didnt call claimRewards
        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 4 ether);
        assertEq(strongHands.unclaimedDividends(), 5 ether); // 6 from Charlie + 1 from Mark but Mark picked up 2 ethers reward from Charlie
        assertEq(strongHands.totalDividendPoints(), 1.25 ether);

        // ! Check Bob - BEFORE WITHDRAWING FROM HIS ACC
        (uint256 balanceBob, uint256 timestampBob, uint256 lastDividendPointsBob) = strongHands.users(BOB);
        assertEq(BOB.balance, 99 ether);
        assertEq(balanceBob, 1 ether); // not updated because Bob didnt call claimRewards
        assertEq(timestampBob, block.timestamp - LOCK_PERIOD);
        assertEq(lastDividendPointsBob, 0); // this is 1 ether - For 1 ether holding, you win 1 ether. He holds 2 ether -> Wins 2 ether prize
        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 4 ether);
        assertEq(strongHands.unclaimedDividends(), 5 ether); // 6 from Charlie + 1 from Mark but Mark picked up 2 ethers reward from Charlie
        assertEq(strongHands.totalDividendPoints(), 1.25 ether);

        // ! Alice Withdraws
        vm.prank(ALICE);
        strongHands.withdraw();

        // ! Check Alice - AFTER WITHDRAWING FROM HER ACC
        (uint256 balanceAliceAfter, uint256 timestampAliceAfter, uint256 lastDividendPointsAliceAfter) =
            strongHands.users(ALICE);
        // 100 - 3 deposited + 3 from Charlie + 3 withdrawn + 0.75 from Mark
        assertEq(ALICE.balance, 103.75 ether);
        assertEq(balanceAliceAfter, 0); // withdrew
        assertEq(timestampAliceAfter, block.timestamp - LOCK_PERIOD);
        assertEq(lastDividendPointsAliceAfter, 1.25 ether); // this is 1 ether from Charlie + 0.25 from Mark - For 1 ether holding, you win 1.25 ether. She holds 3 ether -> Wins 3.75 ether prize
        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 1 ether);
        assertEq(strongHands.unclaimedDividends(), 1.25 ether); // 6 from Charlie and 1 from Mark but Mark picked up 2 ethers reward from Charlie and Alice picked up 3 ethers reward from Charlie and 0.75 from Mark
        assertEq(strongHands.totalDividendPoints(), 1.25 ether);

        // ! Bob Withdraws
        vm.prank(BOB);
        strongHands.withdraw();

        // ! Check Bob - AFTER WITHDRAWING FROM HIS ACC
        (uint256 balanceBobAfter, uint256 timestampBobAfter, uint256 lastDividendPointsBobAfter) =
            strongHands.users(BOB);
        // 100 - 1 deposited + 1 from Charlie + 1 withdrawn + 0.25 from Mark
        assertEq(BOB.balance, 101.25 ether);
        assertEq(balanceBobAfter, 0); // withdrew
        assertEq(timestampBobAfter, block.timestamp - LOCK_PERIOD);
        assertEq(lastDividendPointsBobAfter, 1.25 ether); // this is 1 ether from Charlie + 0.25 from Mark - For 1 ether holding, you win 1.25 ether. He holds 1 ether -> Wins 1.25 ether prize

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 0);
        assertEq(strongHands.unclaimedDividends(), 0); // 6 from Charlie and 1 from Mark but Mark picked up 2 ethers reward from Charlie and Alice picked up 3 ethers reward from Charlie and 0.75 from Mark and Bob picked up 1 ethers reward from Charlie and 0.25 from Mark === 6 + 1 - 2 - 3 - 0.75 - 1 - 0.25
        assertEq(strongHands.totalDividendPoints(), 1.25 ether);
    }

    // TODO -> Alice, Bob, Charlie, Mark and Jane test. First question from email.
    function testFork_Alice_Bob_Active_Charlie_MidPenalty_JaneEnters_NextPenaltyDistribution()
        public
        skipWhenNotForking
        depositWith(BOB, 1 ether)
        depositWith(ALICE, 3 ether)
        depositWith(CHARLIE, 24 ether)
        depositWith(MARK, 2 ether)
    {
        skip(LOCK_PERIOD / 2);
        // ! Charlie withdraws
        vm.prank(CHARLIE);
        strongHands.withdraw();

        // ! Check Charlie
        (uint256 balanceCharlie, uint256 timestampCharlie, uint256 lastDividendPointsCharlie) =
            strongHands.users(CHARLIE);
        assertEq(CHARLIE.balance, 94 ether);
        assertEq(balanceCharlie, 0 ether); // he withdrew
        assertEq(timestampCharlie, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPointsCharlie, 0);

        // ! Check Mark
        (uint256 balanceMark, uint256 timestampMark, uint256 lastDividendPointsMark) = strongHands.users(MARK);
        assertEq(MARK.balance, 98 ether);
        assertEq(balanceMark, 2 ether); // not updated because Mark didnt call claimRewards
        assertEq(timestampMark, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPointsMark, 0); // not updated because Mark didnt call claimRewards

        // ! Check Alice
        (uint256 balanceAlice, uint256 timestampAlice, uint256 lastDividendPointsAlice) = strongHands.users(ALICE);
        assertEq(ALICE.balance, 97 ether);
        assertEq(balanceAlice, 3 ether); // not updated because Alice didnt call claimRewards
        assertEq(timestampAlice, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPointsAlice, 0); // not updated because Alice didnt call claimRewards

        // ! Check Bob
        (uint256 balanceBob, uint256 timestampBob, uint256 lastDividendPointsBob) = strongHands.users(BOB);
        assertEq(BOB.balance, 99 ether);
        assertEq(balanceBob, 1 ether); // not updated because Bob didnt call claimRewards
        assertEq(timestampBob, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPointsBob, 0); // not updated because Bob didnt call claimRewards

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 6 ether);
        assertEq(strongHands.unclaimedDividends(), 6 ether);
        assertEq(strongHands.totalDividendPoints(), 1 ether);

        // TODO -> Jane Enters, Someone else enters and pays fee. How much Jane will get?
        vm.prank(JANE);
        strongHands.deposit{value: 6 ether}();
    }
}
