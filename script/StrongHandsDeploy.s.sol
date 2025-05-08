// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IWrappedTokenGatewayV3} from "@aave/v3-origin/contracts/helpers/interfaces/IWrappedTokenGatewayV3.sol";

import {StrongHands} from "../src/StrongHands.sol";

contract StrongHandsDeploy is Script {
    uint256 public constant LOCK_PERIOD = 365 days;

    // Sepolia addresses -> https://aave.com/docs/resources/addresses
    IWrappedTokenGatewayV3 public constant WRAPPED_TOKEN_GATEWAY_V3 =
        IWrappedTokenGatewayV3(0x387d311e47e80b498169e6fb51d3193167d89F7D);
    address constant POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address constant WETH = 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c;
    address constant A_ETH_WETH = 0x5b071b590a59395fE4025A0Ccc1FcC931AAc1830;

    StrongHands public strongHands;

    function setUp() public {}

    function run() public returns (StrongHands) {
        vm.startBroadcast();

        strongHands = new StrongHands(LOCK_PERIOD, WRAPPED_TOKEN_GATEWAY_V3, POOL, WETH, A_ETH_WETH);

        vm.stopBroadcast();

        return strongHands;
    }
}
