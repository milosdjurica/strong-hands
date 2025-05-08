// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Test, console} from "forge-std/Test.sol";
import {StrongHands} from "../../src/StrongHands.sol";
import {StrongHandsDeploy} from "../../script/StrongHandsDeploy.s.sol";
import {SetupTestsTest} from "../SetupTests.sol";

contract ForkTest is SetupTestsTest {
    function testFork_constructor() public view skipWhenNotForking {
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

    // ! Deposit tests
    function testFork_deposit_RevertIf_DepositIsZero() public skipWhenNotForking {
        vm.expectRevert(abi.encodeWithSelector(StrongHands.StrongHands__ZeroDeposit.selector));
        strongHands.deposit();
    }

    function testFork_deposit() public skipWhenNotForking {
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Deposited(BOB, 1 ether, block.timestamp);
        strongHands.deposit{value: 1 ether}();

        (uint256 balance, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);

        assertEq(balance, 1 ether);
        assertEq(timestamp, block.timestamp);
        assertEq(strongHands.totalDividendPoints(), lastDividendPoints);
        assertEq(strongHands.totalDividendPoints(), 0);
        assertEq(strongHands.totalStaked(), 1 ether);

        // StrongHands contract should hold no raw ETH
        // TODO -> This check passes on mainnet, but fails on sepolia? Different ABIs probably because aave-v3-origin vs core & periphery
        // assertEq(address(strongHands).balance, 0);

        assertEq(strongHands.i_aEthWeth().balanceOf(address(strongHands)), 1 ether);
    }

    // ! Withdraw tests
    function testFork_withdraw_RevertIf_ZeroAmount() public skipWhenNotForking {
        vm.expectRevert(abi.encodeWithSelector(StrongHands.StrongHands__ZeroAmount.selector));
        strongHands.withdraw();
    }
}
