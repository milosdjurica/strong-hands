// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {StrongHands} from "../src/StrongHands.sol";
import {StrongHandsDeploy} from "../script/StrongHandsDeploy.s.sol";

contract StrongHandsTest is Test {
    StrongHands public strongHands;
    StrongHandsDeploy deployScript;

    function setUp() public {
        deployScript = new StrongHandsDeploy();
        strongHands = deployScript.run();
    }

    function test_constructor() public view {
        assertEq(strongHands.i_lockPeriod(), deployScript.LOCK_PERIOD());
        assertEq(strongHands.i_owner(), msg.sender);
    }
}
