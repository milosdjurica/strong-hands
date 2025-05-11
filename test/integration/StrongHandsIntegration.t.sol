// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SetupTestsTest} from "../SetupTests.sol";
import {StrongHands} from "../../src/StrongHands.sol";
import {console} from "forge-std/Test.sol";

contract StrongHandsIntegrationTest is SetupTestsTest {
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // *                                                   Integration Tests                                                            //
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function test_deposit_AfterWithdrewPayingMaxPenalty()
        public
        depositWith(ALICE, 1 ether)
        depositWith(BOB, 2 ether)
    {
        // ! Bob withdraws and pays 50% penalty -> 1 ether
        vm.prank(BOB);
        strongHands.withdraw();

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 1 ether); // Alice 1
        assertEq(strongHands.unclaimedDividends(), 1 ether); // 1 Bob first penalty that Alice didn't claim
        assertEq(strongHands.totalDividendPoints(), 1 ether);

        skip(1);
        // ! Bob deposits
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Deposited(BOB, 1 ether, block.timestamp);
        strongHands.deposit{value: 1 ether}();

        // ! Check Bob
        (uint256 balance, uint256 claimedDividendsBob, uint256 timestamp, uint256 lastDividendPoints) =
            strongHands.users(BOB);
        // Skip this check because Mock doesnt work properly
        // assertEq(BOB.balance, 98 ether);
        assertEq(balance, 1 ether);
        assertEq(claimedDividendsBob, 0);
        assertEq(timestamp, block.timestamp);
        assertEq(lastDividendPoints, 1 ether);

        // ! Check Alice
        (uint256 balanceAlice, uint256 claimedDividendsAlice, uint256 timestampAlice, uint256 lastDividendPointsAlice) =
            strongHands.users(ALICE);
        assertEq(balanceAlice, 1 ether);
        assertEq(claimedDividendsAlice, 0);
        assertEq(timestampAlice, block.timestamp - 1);
        assertEq(lastDividendPointsAlice, 0);

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 2 ether); // Alice 1 + Bob 1
        assertEq(strongHands.unclaimedDividends(), 1 ether); // 1 Bob first penalty that Alice didn't claim
        assertEq(strongHands.totalDividendPoints(), 1 ether);

        vm.prank(ALICE);
        strongHands.claimDividends();

        // ! Check Alice after claiming
        (
            uint256 balanceAliceAfterClaim,
            uint256 claimedDividendsAliceAfterClaim,
            uint256 timestampAliceAfterClaim,
            uint256 lastDividendPointsAliceAfterClaim
        ) = strongHands.users(ALICE);
        assertEq(balanceAliceAfterClaim, 1 ether);
        assertEq(claimedDividendsAliceAfterClaim, 1 ether);
        assertEq(timestampAliceAfterClaim, block.timestamp - 1);
        assertEq(lastDividendPointsAliceAfterClaim, 1 ether);

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 3 ether); // Alice 1 + Bob 1 + Alice 1 claimed
        assertEq(strongHands.unclaimedDividends(), 0);
        assertEq(strongHands.totalDividendPoints(), 1 ether);

        skip(LOCK_PERIOD);
        vm.prank(BOB);
        strongHands.withdraw();
        // ! Check Bob after withdrawing
        (
            uint256 balanceBobAfter,
            uint256 claimedDividendsBobAfter,
            uint256 timestampBobAfter,
            uint256 lastDividendPointsBobAfter
        ) = strongHands.users(BOB);
        // Skip this check because Mock doesnt work properly
        // assertEq(BOB.balance, 98 ether);
        assertEq(balanceBobAfter, 0 ether);
        assertEq(claimedDividendsBobAfter, 0);
        assertEq(timestampBobAfter, block.timestamp - LOCK_PERIOD);
        assertEq(lastDividendPointsBobAfter, 1 ether);

        vm.prank(ALICE);
        strongHands.withdraw();
        // ! Check Bob after withdrawing
        (
            uint256 balanceAliceAfterWithdraw,
            uint256 claimedDividendsAliceAfterWithdraw,
            uint256 timestampAliceAfterWithdraw,
            uint256 lastDividendPointsAliceAfterWithdraw
        ) = strongHands.users(ALICE);
        // Skip this check because Mock doesnt work properly
        // assertEq(BOB.balance, 98 ether);
        assertEq(balanceAliceAfterWithdraw, 0 ether);
        assertEq(claimedDividendsAliceAfterWithdraw, 0);
        assertEq(timestampAliceAfterWithdraw, block.timestamp - LOCK_PERIOD - 1);
        assertEq(lastDividendPointsAliceAfterWithdraw, 1 ether);
    }

    // ! Note -> This test will work only if LOCK_PERIOD % 2 == 0
    function test_withdraw_MidPenalty_AliceClaims() public depositWith(ALICE, 1 ether) depositWith(BOB, 1 ether) {
        skip(LOCK_PERIOD / 2);
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, 0.75 ether, 0.25 ether, block.timestamp);
        strongHands.withdraw();

        (uint256 balance,, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);
        assertEq(balance, 0);
        assertEq(timestamp, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPoints, 0);

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 1 ether);
        assertEq(strongHands.unclaimedDividends(), 0.25 ether);
        assertEq(strongHands.totalDividendPoints(), 0.25 ether);

        skip(LOCK_PERIOD);
        vm.prank(ALICE);
        strongHands.withdraw();
        (uint256 balanceAlice,, uint256 timestampAlice, uint256 lastDividendPointsAlice) = strongHands.users(ALICE);
        assertEq(balanceAlice, 0);
        assertEq(timestampAlice, block.timestamp - LOCK_PERIOD - LOCK_PERIOD / 2);
        assertEq(lastDividendPointsAlice, 0.25 ether);

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 0 ether);
        assertEq(strongHands.unclaimedDividends(), 0 ether);
        assertEq(strongHands.totalDividendPoints(), 0.25 ether);
    }

    function test_calculations() public depositWith(BOB, 6 ether) depositWith(ALICE, 6 ether) {
        vm.prank(BOB);
        strongHands.withdraw();

        // ! Check Bob
        (uint256 balance,, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);
        // assertEq(BOB.balance, 97 ether);
        assertEq(balance, 0 ether);
        assertEq(timestamp, block.timestamp);
        assertEq(lastDividendPoints, 0);

        // ! Check Alice
        (uint256 balanceAlice,, uint256 timestampAlice, uint256 lastDividendPointsAlice) = strongHands.users(ALICE);
        // assertEq(ALICE.balance, 94 ether);
        assertEq(balanceAlice, 6 ether);
        assertEq(timestampAlice, block.timestamp);
        assertEq(lastDividendPointsAlice, 0);

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 6 ether);
        assertEq(strongHands.unclaimedDividends(), 3 ether);
        assertEq(strongHands.totalDividendPoints(), 0.5 ether);

        // ! Alice withdraws after lock period passes. No penalty
        skip(LOCK_PERIOD);
        vm.prank(ALICE);
        strongHands.withdraw();

        // ! Check Alice
        (uint256 balanceAliceAfter,, uint256 timestampAliceAfter, uint256 lastDividendPointsAliceAfter) =
            strongHands.users(ALICE);
        // assertEq(ALICE.balance, 94 ether);
        assertEq(balanceAliceAfter, 0 ether);
        assertEq(timestampAliceAfter, block.timestamp - LOCK_PERIOD);
        assertEq(lastDividendPointsAliceAfter, 0.5 ether);
        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 0);
        assertEq(strongHands.unclaimedDividends(), 0);
        assertEq(lastDividendPointsAliceAfter, 0.5 ether);
    }
}
