// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SetupTestsTest} from "../SetupTests.sol";
import {StrongHands} from "../../src/StrongHands.sol";

contract StrongHandsUnitTest is SetupTestsTest {
    function test_constructor() public view {
        assertEq(strongHands.i_lockPeriod(), deployScript.LOCK_PERIOD());
        assertEq(strongHands.owner(), msg.sender);
    }

    // ! Deposit tests
    function test_deposit_RevertIf_DepositIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(StrongHands.StrongHands__ZeroDeposit.selector));
        strongHands.deposit();
    }

    function test_deposit() public {
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Deposited(BOB, 1 ether, block.timestamp);
        strongHands.deposit{value: 1 ether}();

        (uint256 balance, uint256 timestamp,) = strongHands.users(BOB);

        assertEq(balance, 1 ether);
        assertEq(timestamp, block.timestamp);
        assertEq(strongHands.totalStaked(), 1 ether);
    }

    // ! Withdraw tests
    function test_withdraw_RevertIf_ZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(StrongHands.StrongHands__ZeroAmount.selector));
        strongHands.withdraw();
    }

    function test_withdraw_ZeroFee() public depositWithBob {
        skip(deployScript.LOCK_PERIOD());
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, 1 ether, 0, block.timestamp);
        strongHands.withdraw();

        (uint256 balance,,) = strongHands.users(BOB);
        assertEq(balance, 0);
        // assertEq(timestamp, block.timestamp);
        assertEq(strongHands.totalStaked(), 0);
    }

    function test_withdraw_MaxFee() public depositWithBob {
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, 0.5 ether, 0.5 ether, block.timestamp);
        strongHands.withdraw();

        (uint256 balance,,) = strongHands.users(BOB);
        assertEq(balance, 0);
        // assertEq(timestamp, block.timestamp);
        assertEq(strongHands.totalStaked(), 0);
    }

    // Note -> This test will work only if LOCK_PERIOD % 2 == 0
    function test_withdraw_MidFee() public depositWithBob {
        skip(deployScript.LOCK_PERIOD() / 2);
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, 0.75 ether, 0.25 ether, block.timestamp);
        strongHands.withdraw();

        (uint256 balance,,) = strongHands.users(BOB);
        assertEq(balance, 0);
        // assertEq(timestamp, block.timestamp);
        assertEq(strongHands.totalStaked(), 0);
    }

    // TODO -> Tests with multiple deposits, multiple withdraws, combinations, same user deposits many times, test transfer fails, etc...
}
