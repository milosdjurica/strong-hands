// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {StrongHands} from "../src/StrongHands.sol";
import {StrongHandsDeploy} from "../script/StrongHandsDeploy.s.sol";

contract SetupTestsTest is Test {
    StrongHands public strongHands;
    StrongHandsDeploy public deployScript;

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

    // Helper modifier
    modifier depositWith(address user, uint256 amount) {
        vm.prank(user);
        strongHands.deposit{value: amount}();
        _;
    }

    // TODO -> Tests with multiple deposits, multiple withdraws, combinations, same user deposits many times, test transfer fails, etc...
}
