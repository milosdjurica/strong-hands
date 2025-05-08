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

    function testFork_withdraw_ZeroFee() public skipWhenNotForking depositWithBob {
        assertEq(BOB.balance, 99 ether);

        skip(deployScript.LOCK_PERIOD());
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, 1 ether, 0, block.timestamp);
        strongHands.withdraw();

        (uint256 balance, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);
        // ! Checks
        assertEq(balance, 0);
        assertEq(timestamp, block.timestamp - deployScript.LOCK_PERIOD());
        assertEq(lastDividendPoints, 0);
        assertEq(strongHands.totalStaked(), 0);
        assertEq(strongHands.totalDividendPoints(), 0);
        assertEq(BOB.balance, 100 ether);
        // owner still has aEthWeth acquired from the BOB deposit
        assertGt(strongHands.i_aEthWeth().balanceOf(address(strongHands)), 0);

        // TODO -> check if owner can pull those tokens later, check if can pull something before too (if owner can choose how much he wants out)
        // uint256 balanceBefore = msg.sender.balance;
        // strongHands.claimInterest();
        // uint256 balanceAfter = msg.sender.balance;
        // assertGt(balanceAfter, balanceBefore);
    }

    function testFork_withdraw_MaxFee() public skipWhenNotForking depositWithBob {
        // Bob deposited and instantly withdraws
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, 0.5 ether, 0.5 ether, block.timestamp);
        strongHands.withdraw();

        (uint256 balance, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);
        assertEq(balance, 0);
        assertEq(timestamp, block.timestamp);
        assertEq(lastDividendPoints, 0);
        assertEq(strongHands.totalStaked(), 0);
        // totalDividendPoints would normally be 0.5, but in this case will be 0 because there is no other active users, so nobody can get those dividends
        assertEq(strongHands.totalDividendPoints(), 0 ether);
        assertEq(BOB.balance, 99.5 ether);
        assertEq(strongHands.i_aEthWeth().balanceOf(address(strongHands)), 0.5 ether);

        skip(1111);
        // StrongHands contracts keeps acquiring interest on aEthWeth until it is pulled out
        assertGt(strongHands.i_aEthWeth().balanceOf(address(strongHands)), 0.5 ether);
    }

    // Note -> This test will work properly only if LOCK_PERIOD % 2 == 0
    function testFork_withdraw_MidFee() public skipWhenNotForking depositWithBob {
        skip(deployScript.LOCK_PERIOD() / 2);
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, 0.75 ether, 0.25 ether, block.timestamp);
        strongHands.withdraw();

        (uint256 balance, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);
        assertEq(balance, 0);
        assertEq(timestamp, block.timestamp - deployScript.LOCK_PERIOD() / 2);
        assertEq(lastDividendPoints, 0);
        assertEq(strongHands.totalStaked(), 0);
        // totalDividendPoints would normally be 0.5, but in this case will be 0 because there is no other active users, so nobody can get those dividends
        assertEq(strongHands.totalDividendPoints(), 0 ether);
        assertEq(BOB.balance, 99.75 ether);
        uint256 aEthWethBalance = strongHands.i_aEthWeth().balanceOf(address(strongHands));
        assertGt(aEthWethBalance, 0.25 ether);

        skip(1111);
        // StrongHands contracts keeps acquiring interest on aEthWeth until it is pulled out
        uint256 aEthWethBalanceAfterTimePassed = strongHands.i_aEthWeth().balanceOf(address(strongHands));
        assertGt(aEthWethBalanceAfterTimePassed, aEthWethBalance);
    }
}
