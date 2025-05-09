// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {StrongHands} from "../src/StrongHands.sol";
import {StrongHandsDeploy} from "../script/StrongHandsDeploy.s.sol";

contract SetupTestsTest is Test {
    StrongHands public strongHands;
    StrongHandsDeploy public deployScript;
    uint256 LOCK_PERIOD;

    address BOB = makeAddr("BOB");
    address ALICE = makeAddr("ALICE");
    address CHARLIE = makeAddr("CHARLIE");
    address MARK = makeAddr("MARK");
    address JANE = makeAddr("JANE");
    address MIA = makeAddr("MIA");

    event Deposited(address indexed sender, uint256 indexed amount, uint256 indexed timestamp);
    event Withdrawn(address indexed user, uint256 indexed payout, uint256 indexed penalty, uint256 timestamp);

    function setUp() public {
        deployScript = new StrongHandsDeploy();
        strongHands = deployScript.run();
        vm.deal(BOB, 100 ether);
        vm.deal(ALICE, 100 ether);
        vm.deal(CHARLIE, 100 ether);
        vm.deal(MARK, 100 ether);
        vm.deal(JANE, 100 ether);
        vm.deal(MIA, 100 ether);

        LOCK_PERIOD = deployScript.LOCK_PERIOD();
    }

    // Helper modifier
    modifier depositWith(address user, uint256 amount) {
        vm.prank(user);
        strongHands.deposit{value: amount}();
        _;
    }

    // TODO -> Tests with multiple deposits, multiple withdraws, combinations, same user deposits many times, test transfer fails, etc...
}
