// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {StrongHands, IWrappedTokenGatewayV3, IPool, IERC20} from "../../src/StrongHands.sol";

import {SetupTestsTest} from "../SetupTests.sol";
import {StrongHands} from "../../src/StrongHands.sol";
import {console} from "forge-std/Test.sol";

contract StrongHandsHarnessContract is StrongHands {
    constructor(uint256 _lockPeriod, IWrappedTokenGatewayV3 _wrappedTokenGatewayV3, IPool _pool, IERC20 _aEthWeth)
        StrongHands(_lockPeriod, _wrappedTokenGatewayV3, _pool, _aEthWeth)
    {}

    // Exposing _dividendsOwing() function for testing
    function harnessDividendsOwing(address userAddr) external view returns (uint256) {
        return _dividendsOwing(users[userAddr]);
    }
}

contract StrongHandsHarnessTest is SetupTestsTest {
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // *                                          Harness (internal functions) Tests                                                    //
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////
    // * _dividendsOwing() Tests //
    ///////////////////////////////
    function test_dividendsOwing_Zero() public {
        StrongHandsHarnessContract harness = new StrongHandsHarnessContract(
            deployScript.LOCK_PERIOD(), deployScript.wrappedTokenGatewayV3(), deployScript.pool(), deployScript.aWeth()
        );

        vm.prank(BOB);
        harness.deposit{value: 1 ether}();
        assertEq(harness.harnessDividendsOwing(BOB), 0);
    }

    function test_dividendsOwing() public {
        StrongHandsHarnessContract harness = new StrongHandsHarnessContract(
            deployScript.LOCK_PERIOD(), deployScript.wrappedTokenGatewayV3(), deployScript.pool(), deployScript.aWeth()
        );

        vm.prank(BOB);
        harness.deposit{value: 1 ether}();
        assertEq(harness.harnessDividendsOwing(BOB), 0);

        vm.startPrank(ALICE);
        harness.deposit{value: 2 ether}();
        harness.withdraw();
        vm.stopPrank();

        assertEq(harness.harnessDividendsOwing(BOB), 1 ether);
    }
}
