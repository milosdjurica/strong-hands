// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IWrappedTokenGatewayV3} from "@aave/v3-origin/contracts/helpers/interfaces/IWrappedTokenGatewayV3.sol";
import {IPool} from "@aave/v3-origin/contracts/interfaces/IPool.sol";
import {IWETH} from "@aave/v3-origin/contracts/helpers/interfaces/IWETH.sol";
import {IERC20} from "@aave/v3-origin/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

import {StrongHands} from "../src/StrongHands.sol";
import {WrappedTokenGatewayV3Mock} from "../test/mocks/WrappedTokenGatewayV3Mock.sol";
import {PoolMock} from "../test/mocks/PoolMock.sol";
import {WETHMock} from "../test/mocks/WETHMock.sol";
import {AWethMock} from "../test/mocks/AWethMock.sol";

contract StrongHandsDeploy is Script {
    uint256 public constant LOCK_PERIOD = 365 days;

    // Sepolia addresses -> https://aave.com/docs/resources/addresses
    IWrappedTokenGatewayV3 public constant WRAPPED_TOKEN_GATEWAY_V3 =
        IWrappedTokenGatewayV3(0x387d311e47e80b498169e6fb51d3193167d89F7D);
    IPool constant POOL = IPool(0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951);
    IWETH constant WETH = IWETH(0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c);
    IERC20 constant A_WETH = IERC20(0x5b071b590a59395fE4025A0Ccc1FcC931AAc1830);

    StrongHands public strongHands;

    function setUp() public {}

    function run() public returns (StrongHands) {
        vm.startBroadcast();

        IWrappedTokenGatewayV3 wrappedGateway;
        IPool pool;
        IWETH weth;
        IERC20 aWeth;

        if (block.chainid == 31337) {
            // Deploy mocks
            WrappedTokenGatewayV3Mock gatewayMock = new WrappedTokenGatewayV3Mock();
            PoolMock poolMock = new PoolMock();
            WETHMock wethMock = new WETHMock();
            AWethMock aTokenMock = new AWethMock();

            wrappedGateway = IWrappedTokenGatewayV3(address(gatewayMock));
            pool = IPool(address(poolMock));
            weth = IWETH(address(wethMock));
            aWeth = IERC20(address(aTokenMock));
        } else if (block.chainid == 11155111) {
            // Sepolia addresses
            wrappedGateway = WRAPPED_TOKEN_GATEWAY_V3;
            pool = POOL;
            weth = WETH;
            aWeth = A_WETH;
        }

        strongHands = new StrongHands(LOCK_PERIOD, wrappedGateway, pool, weth, aWeth);

        vm.stopBroadcast();

        return strongHands;
    }
}
