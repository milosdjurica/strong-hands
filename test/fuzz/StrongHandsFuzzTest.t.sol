// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SetupTestsTest} from "../SetupTests.sol";
import {StrongHands} from "../../src/StrongHands.sol";

contract StrongHandsFuzzTest is SetupTestsTest {
    // ! Deposit tests
    function testFuzz_deposit(uint256 amountToDeposit) public {
        amountToDeposit = bound(amountToDeposit, 1, 100 ether);

        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Deposited(BOB, amountToDeposit, block.timestamp);
        strongHands.deposit{value: amountToDeposit}();

        (uint256 balance, uint256 timestamp,) = strongHands.users(BOB);

        assertEq(balance, amountToDeposit);
        assertEq(timestamp, block.timestamp);
        assertEq(strongHands.totalStaked(), amountToDeposit);
    }

    // ! Withdraw tests
    function testFuzz_withdraw_RandomFee(uint256 timePassed) public depositWith(BOB, 1 ether) {
        timePassed = bound(timePassed, 0, deployScript.LOCK_PERIOD());
        skip(timePassed);
        uint256 timeLeft = deployScript.LOCK_PERIOD() - timePassed;

        uint256 expectedFee = 1 ether * timeLeft / deployScript.LOCK_PERIOD() * 50 / 100;
        uint256 expectedPayout = 1 ether - expectedFee;

        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, expectedPayout, expectedFee, block.timestamp);
        strongHands.withdraw();

        (uint256 balance,,) = strongHands.users(BOB);
        assertEq(balance, 0);
        // assertEq(timestamp, block.timestamp);
        assertEq(strongHands.totalStaked(), 0);
    }
}
