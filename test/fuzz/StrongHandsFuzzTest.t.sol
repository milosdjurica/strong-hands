// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {console} from "forge-std/Test.sol";
import {SetupTestsTest} from "../SetupTests.sol";
import {StrongHands} from "../../src/StrongHands.sol";

contract StrongHandsFuzzTest is SetupTestsTest {
    // TODO -> Write tests for other functions

    ////////////////////////////
    // * deposit() tests 	  //
    ////////////////////////////
    function testFuzz_deposit(uint256 amountToDeposit) public {
        amountToDeposit = bound(amountToDeposit, 1, 100 ether);

        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Deposited(BOB, amountToDeposit, block.timestamp);
        strongHands.deposit{value: amountToDeposit}();

        (uint256 balance,, uint256 timestamp,) = strongHands.users(BOB);

        assertEq(balance, amountToDeposit);
        assertEq(timestamp, block.timestamp);
        assertEq(strongHands.totalStaked(), amountToDeposit);
    }

    ////////////////////////////
    // * withdraw() tests 	  //
    ////////////////////////////
    function testFuzz_withdraw_RandomPenalty(uint256 timePassed) public depositWith(BOB, 1 ether) {
        timePassed = bound(timePassed, 0, LOCK_PERIOD);
        skip(timePassed);
        uint256 timeLeft = LOCK_PERIOD - timePassed;

        uint256 expectedPenalty = 1 ether * timeLeft / LOCK_PERIOD * 50 / 100;
        uint256 expectedPayout = 1 ether - expectedPenalty;

        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, expectedPayout, expectedPenalty, block.timestamp);
        strongHands.withdraw();

        (uint256 balance,,,) = strongHands.users(BOB);
        assertEq(balance, 0);
        // assertEq(timestamp, block.timestamp);
        assertEq(strongHands.totalStaked(), 0);
    }

    ////////////////////////////////
    // * claimDividends() tests   //
    ////////////////////////////////
    function testFuzz_claimDividends(uint256 aliceAmount) public depositWith(BOB, 1 ether) {
        aliceAmount = bound(aliceAmount, 1, 100 ether);
        vm.prank(ALICE);
        strongHands.deposit{value: aliceAmount}();

        vm.prank(ALICE);
        strongHands.withdraw();

        skip(LOCK_PERIOD);
        vm.prank(BOB);
        strongHands.claimDividends();

        (uint256 balance, uint256 claimedDividends,,) = strongHands.users(BOB);
        assertEq(balance, 1 ether);
        assertEq(claimedDividends, aliceAmount / 2);
    }

    ////////////////////////////////
    // * calculatePenalty() tests //
    ////////////////////////////////
    function testFuzz_CalculatePenalty(uint64 amountBob, uint64 amountAlice, uint256 skipValue) public {
        // ! Not 0 to avoid revert
        vm.assume(amountAlice != 0);
        vm.assume(amountBob != 0);
        skipValue = bound(skipValue, 1, block.timestamp + LOCK_PERIOD - 1);

        // ! Deposits
        vm.prank(BOB);
        strongHands.deposit{value: amountBob}();
        vm.prank(ALICE);
        strongHands.deposit{value: amountAlice}();

        // ! Skip to have random penalty.
        skip(skipValue);
        vm.prank(BOB);
        uint256 penalty = strongHands.calculatePenalty(BOB);

        (uint256 balance,, uint256 lastDepositTimestamp,) = strongHands.users(BOB);

        uint256 unlockTimestamp = lastDepositTimestamp + LOCK_PERIOD;
        uint256 timeLeft = unlockTimestamp - block.timestamp;
        uint256 expectedPenalty = balance * timeLeft / LOCK_PERIOD / 2;

        assertEq(penalty, expectedPenalty);
    }
}
