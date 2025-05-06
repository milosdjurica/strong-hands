// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {StrongHands} from "../src/StrongHands.sol";
import {StrongHandsDeploy} from "../script/StrongHandsDeploy.s.sol";

contract StrongHandsTest is Test {
    StrongHands public strongHands;
    StrongHandsDeploy deployScript;

    address BOB = makeAddr("BOB");
    address ALICE = makeAddr("ALICE");

    event Deposited(address sender, uint256 amount, uint256 timestamp);

    function setUp() public {
        deployScript = new StrongHandsDeploy();
        strongHands = deployScript.run();
        vm.deal(BOB, 100 ether);
        vm.deal(ALICE, 100 ether);
    }

    function test_constructor() public view {
        assertEq(strongHands.i_lockPeriod(), deployScript.LOCK_PERIOD());
        assertEq(strongHands.i_owner(), msg.sender);
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

        (uint256 amount, uint256 timestamp) = strongHands.users(BOB);

        assertEq(amount, 1 ether);
        assertEq(timestamp, block.timestamp);
    }

    function testFuzz_deposit(uint256 amountToDeposit) public {
        amountToDeposit = bound(amountToDeposit, 1, 100 ether);

        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Deposited(BOB, amountToDeposit, block.timestamp);
        strongHands.deposit{value: amountToDeposit}();

        (uint256 amount, uint256 timestamp) = strongHands.users(BOB);

        assertEq(amount, amountToDeposit);
        assertEq(timestamp, block.timestamp);
    }

    // ! Withdraw tests
}
