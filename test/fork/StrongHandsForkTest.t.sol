// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Test, console} from "forge-std/Test.sol";
import {StrongHands} from "../../src/StrongHands.sol";
import {StrongHandsDeploy} from "../../script/StrongHandsDeploy.s.sol";
import {SetupTestsTest} from "../SetupTests.sol";

contract ForkTest is SetupTestsTest {
    modifier skipWhenNotForkTesting() {
        if (block.chainid == 31337) {
            console.log("Skipping test: running on Anvil without fork.");
            return;
        }
        _;
    }

    function testFork_Constructor() public view skipWhenNotForkTesting {
        if (block.chainid == 11155111) {
            assertEq(strongHands.i_lockPeriod(), deployScript.LOCK_PERIOD());
            assertEq(strongHands.owner(), msg.sender);
            assertEq(address(strongHands.i_wrappedTokenGatewayV3()), address(deployScript.WRAPPED_TOKEN_GATEWAY_V3()));
            assertEq(address(strongHands.i_pool()), address(deployScript.POOL()));
            assertEq(address(strongHands.i_WETH()), address(deployScript.WETH()));
            assertEq(address(strongHands.i_aEthWeth()), address(deployScript.A_WETH()));
        } else {
            assertEq(strongHands.i_lockPeriod(), deployScript.LOCK_PERIOD());
            assertEq(strongHands.owner(), msg.sender);
            assertEq(
                address(strongHands.i_wrappedTokenGatewayV3()), address(deployScript.WRAPPED_TOKEN_GATEWAY_V3_MAINNET())
            );
            assertEq(address(strongHands.i_pool()), address(deployScript.POOL_MAINNET()));
            assertEq(address(strongHands.i_WETH()), address(deployScript.WETH_MAINNET()));
            assertEq(address(strongHands.i_aEthWeth()), address(deployScript.A_WETH_MAINNET()));
        }
    }
}
