// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {StrongHands} from "../src/StrongHands.sol";

contract StrongHandsDeploy is Script {
    uint256 public constant LOCK_PERIOD = 11111;

    StrongHands public strongHands;

    function setUp() public {}

    function run() public returns (StrongHands) {
        vm.startBroadcast();

        strongHands = new StrongHands(LOCK_PERIOD);

        vm.stopBroadcast();

        return strongHands;
    }
}
