// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {StrongHands} from "../src/StrongHands.sol";
import {IWrappedTokenGatewayV3} from "../src/interfaces/IWrappedTokenGatewayV3.sol";

contract StrongHandsDeploy is Script {
    uint256 public constant LOCK_PERIOD = 365 days;
    IWrappedTokenGatewayV3 public constant AAVE_WRAPPED_TOKEN_GATEWAY_V3 =
        IWrappedTokenGatewayV3(0x387d311e47e80b498169e6fb51d3193167d89F7D);

    StrongHands public strongHands;

    function setUp() public {}

    function run() public returns (StrongHands) {
        vm.startBroadcast();

        strongHands = new StrongHands(LOCK_PERIOD, AAVE_WRAPPED_TOKEN_GATEWAY_V3);

        vm.stopBroadcast();

        return strongHands;
    }
}
