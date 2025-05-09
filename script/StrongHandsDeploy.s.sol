// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IWrappedTokenGatewayV3} from "@aave/v3-origin/contracts/helpers/interfaces/IWrappedTokenGatewayV3.sol";
import {IPool} from "@aave/v3-origin/contracts/interfaces/IPool.sol";
// import {IWETH} from "@aave/v3-origin/contracts/helpers/interfaces/IWETH.sol";
import {IERC20} from "@aave/v3-origin/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

import {StrongHands} from "../src/StrongHands.sol";
import {WrappedTokenGatewayV3Mock} from "../test/mocks/WrappedTokenGatewayV3Mock.sol";
import {PoolMock} from "../test/mocks/PoolMock.sol";
// import {WETHMock} from "../test/mocks/WETHMock.sol";
import {AWethMock} from "../test/mocks/AWethMock.sol";

contract StrongHandsDeploy is Script {
    uint256 public constant LOCK_PERIOD = 365 days;

    // Sepolia addresses -> https://aave.com/docs/resources/addresses
    IWrappedTokenGatewayV3 public constant WRAPPED_TOKEN_GATEWAY_V3 =
        IWrappedTokenGatewayV3(0x387d311e47e80b498169e6fb51d3193167d89F7D);
    IPool public constant POOL = IPool(0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951);
    // IWETH public constant WETH = IWETH(0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c);
    IERC20 public constant A_WETH = IERC20(0x5b071b590a59395fE4025A0Ccc1FcC931AAc1830);

    // Mainnet addresses -> https://aave.com/docs/resources/addresses
    IWrappedTokenGatewayV3 public constant WRAPPED_TOKEN_GATEWAY_V3_MAINNET =
        IWrappedTokenGatewayV3(0xd01607c3C5eCABa394D8be377a08590149325722);
    IPool public constant POOL_MAINNET = IPool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    // IWETH public constant WETH_MAINNET = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 public constant A_WETH_MAINNET = IERC20(0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8);

    StrongHands public strongHands;
    IWrappedTokenGatewayV3 wrappedTokenGatewayV3;
    IPool pool;
    // IWETH weth;
    IERC20 aWeth;

    function setUp() public {
        if (block.chainid == 31337) {
            // Deploy mocks
            WrappedTokenGatewayV3Mock gatewayMock = new WrappedTokenGatewayV3Mock();
            PoolMock poolMock = new PoolMock();
            // WETHMock wethMock = new WETHMock();
            AWethMock aTokenMock = new AWethMock();

            wrappedTokenGatewayV3 = IWrappedTokenGatewayV3(address(gatewayMock));
            pool = IPool(address(poolMock));
            // weth = IWETH(address(wethMock));
            aWeth = IERC20(address(aTokenMock));
        } else if (block.chainid == 11155111) {
            // Sepolia addresses
            wrappedTokenGatewayV3 = WRAPPED_TOKEN_GATEWAY_V3;
            pool = POOL;
            // weth = WETH;
            aWeth = A_WETH;
        } else {
            // Mainnet
            wrappedTokenGatewayV3 = WRAPPED_TOKEN_GATEWAY_V3_MAINNET;
            pool = POOL_MAINNET;
            // weth = WETH_MAINNET;
            aWeth = A_WETH_MAINNET;
        }
    }

    function run() public returns (StrongHands) {
        setUp();
        vm.startBroadcast();
        strongHands = new StrongHands(LOCK_PERIOD, wrappedTokenGatewayV3, pool, aWeth);
        vm.stopBroadcast();

        return strongHands;
    }
}
