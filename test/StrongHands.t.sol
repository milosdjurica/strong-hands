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

    event Deposited(address indexed sender, uint256 indexed amount, uint256 indexed timestamp);
    event Withdrawn(address indexed user, uint256 indexed payout, uint256 indexed penalty, uint256 timestamp);

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
        assertEq(strongHands.totalStaked(), 1 ether);
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
        assertEq(strongHands.totalStaked(), amountToDeposit);
    }

    // ! Withdraw tests
    function test_withdraw_RevertIf_ZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(StrongHands.StrongHands__ZeroAmount.selector));
        strongHands.withdraw();
    }

    // Helper modifier
    modifier depositWithBob() {
        vm.prank(BOB);
        strongHands.deposit{value: 1 ether}();
        _;
    }

    function test_withdraw_ZeroFee() public depositWithBob {
        skip(deployScript.LOCK_PERIOD());
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, 1 ether, 0, block.timestamp);
        strongHands.withdraw();

        (uint256 amount,) = strongHands.users(BOB);
        assertEq(amount, 0);
        // assertEq(timestamp, block.timestamp);
        assertEq(strongHands.totalStaked(), 0);
    }

    function test_withdraw_MaxFee() public depositWithBob {
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, 0.5 ether, 0.5 ether, block.timestamp);
        strongHands.withdraw();

        (uint256 amount,) = strongHands.users(BOB);
        assertEq(amount, 0);
        // assertEq(timestamp, block.timestamp);
        assertEq(strongHands.totalStaked(), 0);
    }

    function test_withdraw_MidFee() public depositWithBob {
        skip(deployScript.LOCK_PERIOD() / 2);
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, 0.75 ether, 0.25 ether, block.timestamp);
        strongHands.withdraw();

        (uint256 amount,) = strongHands.users(BOB);
        assertEq(amount, 0);
        // assertEq(timestamp, block.timestamp);
        assertEq(strongHands.totalStaked(), 0);
    }

    function testFuzz_withdraw_RandomFee(uint256 timePassed) public depositWithBob {
        timePassed = bound(timePassed, 0, deployScript.LOCK_PERIOD());
        skip(timePassed);
        uint256 timeLeft = deployScript.LOCK_PERIOD() - timePassed;

        uint256 expectedFee = 1 ether * timeLeft / deployScript.LOCK_PERIOD() * 50 / 100;
        uint256 expectedPayout = 1 ether - expectedFee;

        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, expectedPayout, expectedFee, block.timestamp);
        strongHands.withdraw();

        (uint256 amount,) = strongHands.users(BOB);
        assertEq(amount, 0);
        // assertEq(timestamp, block.timestamp);
        assertEq(strongHands.totalStaked(), 0);
    }

    // TODO -> Tests with multiple deposits, multiple withdraws, combinations, same user deposits many times
}
