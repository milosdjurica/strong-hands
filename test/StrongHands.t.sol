// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {StrongHands} from "../src/StrongHands.sol";
import {StrongHandsDeploy} from "../script/StrongHandsDeploy.s.sol";

contract StrongHandsTest is Test {
    StrongHands public strongHands;

    function setUp() public {
        StrongHandsDeploy deploy = new StrongHandsDeploy();
        strongHands = deploy.run();
    }
}
