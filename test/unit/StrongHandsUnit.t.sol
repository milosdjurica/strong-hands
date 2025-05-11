// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SetupTestsTest} from "../SetupTests.sol";
import {StrongHands} from "../../src/StrongHands.sol";
import {console} from "forge-std/Test.sol";

contract StrongHandsUnitTest is SetupTestsTest {
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // *                                                   Unit Tests                                                                   //
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    //////////////////////////
    // * constructor() Test //
    //////////////////////////
    function test_constructor() public view {
        assertEq(strongHands.i_lockPeriod(), LOCK_PERIOD);
        assertEq(strongHands.owner(), msg.sender);
        assertEq(address(strongHands.i_wrappedTokenGatewayV3()), address(deployScript.wrappedTokenGatewayV3()));
        assertEq(address(strongHands.i_pool()), address(deployScript.pool()));
        assertEq(address(strongHands.i_aEthWeth()), address(deployScript.aWeth()));
    }

    /////////////////////////
    // * deposit() Tests   //
    /////////////////////////
    function test_deposit_RevertIf_DepositIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(StrongHands.StrongHands__ZeroDeposit.selector));
        strongHands.deposit();
    }

    function test_deposit_FirstTime() public {
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Deposited(BOB, 1 ether, block.timestamp);
        strongHands.deposit{value: 1 ether}();

        // ! Check Bob
        (uint256 balance,, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);
        assertEq(BOB.balance, 99 ether);
        assertEq(balance, 1 ether);
        assertEq(timestamp, block.timestamp);
        assertEq(lastDividendPoints, 0);

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 1 ether);
        assertEq(strongHands.unclaimedDividends(), 0);
        assertEq(strongHands.totalDividendPoints(), 0);
    }

    function test_deposit_SecondTime() public depositWith(ALICE, 1 ether) depositWith(BOB, 1 ether) {
        skip(1);
        // ! Bob deposits
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Deposited(BOB, 1 ether, block.timestamp);
        strongHands.deposit{value: 1 ether}();

        // ! Check Bob
        (uint256 balance,, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);
        assertEq(BOB.balance, 98 ether);
        assertEq(balance, 2 ether);
        assertEq(timestamp, block.timestamp);
        assertEq(lastDividendPoints, 0);

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 3 ether);
        assertEq(strongHands.unclaimedDividends(), 0);
        assertEq(strongHands.totalDividendPoints(), 0);
    }

    /////////////////////////
    // * withdraw() Tests  //
    /////////////////////////
    function test_withdraw_RevertIf_ZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(StrongHands.StrongHands__ZeroAmount.selector));
        strongHands.withdraw();
    }

    function test_withdraw_ZeroPenalty() public depositWith(BOB, 1 ether) {
        skip(LOCK_PERIOD);
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, 1 ether, 0, block.timestamp);
        strongHands.withdraw();

        // ! Check Bob
        (uint256 balance,, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);
        assertEq(balance, 0);
        assertEq(timestamp, block.timestamp - LOCK_PERIOD);
        assertEq(lastDividendPoints, 0);
        assertEq(strongHands.totalStaked(), 0);

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 0 ether);
        assertEq(strongHands.unclaimedDividends(), 0 ether);
        assertEq(strongHands.totalDividendPoints(), 0 ether);
    }

    function test_withdraw_MaxPenalty() public depositWith(BOB, 1 ether) {
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, 0.5 ether, 0.5 ether, block.timestamp);
        strongHands.withdraw();

        // ! Check Bob
        (uint256 balance,, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);
        assertEq(balance, 0);
        assertEq(timestamp, block.timestamp);
        assertEq(lastDividendPoints, 0);

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 0 ether);
        assertEq(strongHands.unclaimedDividends(), 0 ether); // it is 0 because there are no other users in the system -> no one to claim
        assertEq(strongHands.totalDividendPoints(), 0 ether);
    }

    // ! Note -> This test will work only if LOCK_PERIOD % 2 == 0
    function test_withdraw_MidPenalty() public depositWith(BOB, 1 ether) {
        skip(LOCK_PERIOD / 2);
        vm.prank(BOB);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(BOB, 0.75 ether, 0.25 ether, block.timestamp);
        strongHands.withdraw();

        // ! Check Bob
        (uint256 balance,, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);
        assertEq(balance, 0);
        assertEq(timestamp, block.timestamp - LOCK_PERIOD / 2);
        assertEq(lastDividendPoints, 0);

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 0 ether);
        assertEq(strongHands.unclaimedDividends(), 0 ether); // it is 0 because there are no other users in the system -> no one to claim
        assertEq(strongHands.totalDividendPoints(), 0 ether);
    }

    ////////////////////////////////
    // * collectYield() tests     //
    ////////////////////////////////
    function test_collectYield_RevertIf_NotOwner() public depositWith(BOB, 1 ether) {
        vm.expectRevert("Ownable: caller is not the owner");
        strongHands.claimYield(1);
    }

    function test_collectYield_RevertIf_ZeroAmount() public depositWith(BOB, 1 ether) {
        vm.prank(msg.sender);
        vm.expectRevert(abi.encodeWithSelector(StrongHands.StrongHands__ZeroAmount.selector));
        strongHands.claimYield(0);
    }

    function test_collectYield_RevertIf_NotEnoughYield() public depositWith(BOB, 1 ether) {
        vm.prank(msg.sender);
        vm.expectRevert(abi.encodeWithSelector(StrongHands.StrongHands__NotEnoughYield.selector, 1, 0));
        strongHands.claimYield(1);
    }

    //////////////////////////////
    // * claimDividends() Tests //
    //////////////////////////////
    function test_claimDividends_NoUpdate() public depositWith(BOB, 1 ether) {
        vm.prank(BOB);
        // Won't emit event because he didn't claim any new dividends
        // vm.expectEmit(true, true, true, true);
        // emit ClaimedDividends(BOB, 0, 0, 0);
        strongHands.claimDividends();

        // ! Check Bob
        (uint256 balance,, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);
        assertEq(balance, 1 ether);
        assertEq(timestamp, block.timestamp);
        assertEq(lastDividendPoints, 0);

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 1 ether);
        assertEq(strongHands.unclaimedDividends(), 0);
        assertEq(strongHands.totalDividendPoints(), 0);
    }

    function test_claimDividends_NoUpdate_MultipleDeposits()
        public
        depositWith(ALICE, 1 ether)
        depositWith(BOB, 1 ether)
    {
        vm.startPrank(BOB);
        // Won't emit event because he didn't claim any new dividends
        // vm.expectEmit(true, true, true, true);
        // emit ClaimedDividends(BOB, 0, 0, 0);
        strongHands.claimDividends();
        strongHands.deposit{value: 1 ether}();
        // Won't emit event because he didn't claim any new dividends
        // vm.expectEmit(true, true, true, true);
        // emit ClaimedDividends(BOB, 0, 0, 0);
        strongHands.claimDividends();
        vm.stopPrank();

        // ! Check Bob
        (uint256 balance,, uint256 timestamp, uint256 lastDividendPoints) = strongHands.users(BOB);
        assertEq(balance, 2 ether);
        assertEq(timestamp, block.timestamp);
        assertEq(lastDividendPoints, 0);

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 3 ether);
        assertEq(strongHands.unclaimedDividends(), 0);
        assertEq(strongHands.totalDividendPoints(), 0);
    }

    function test_claimDividends_Update() public depositWith(ALICE, 1 ether) depositWith(BOB, 1 ether) {
        vm.prank(BOB);
        // Won't emit event because he didn't claim any new dividends
        // vm.expectEmit(true, true, true, true);
        // emit ClaimedDividends(BOB, 0, 0, 0);
        strongHands.claimDividends();

        // ! Alice pays 50% -> 0.5 eth
        vm.prank(ALICE);
        strongHands.withdraw();

        vm.startPrank(BOB);
        vm.expectEmit(true, true, true, true);
        emit ClaimedDividends(BOB, 0.5 ether, 0.5 ether, 0);
        strongHands.deposit{value: 1 ether}();
        // Won't emit event because he didn't claim any new dividends
        // vm.expectEmit(true, true, true, true);
        // emit ClaimedDividends(BOB, 0, 0.5 ether, 0.5 ether);
        strongHands.claimDividends();
        vm.stopPrank();

        // ! Check Bob
        (uint256 balance, uint256 claimedDividends, uint256 timestamp, uint256 lastDividendPoints) =
            strongHands.users(BOB);
        assertEq(balance, 2 ether); // 1 + 1 from deposits
        assertEq(claimedDividends, 0.5 ether);
        assertEq(timestamp, block.timestamp);
        assertEq(lastDividendPoints, 0.5 ether);

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 2.5 ether);
        assertEq(strongHands.unclaimedDividends(), 0);
        assertEq(strongHands.totalDividendPoints(), 0.5 ether);

        // ! Bob withdraws without penalty
        skip(LOCK_PERIOD);
        vm.prank(BOB);
        strongHands.withdraw();

        // ! Charlie enters
        vm.prank(CHARLIE);
        strongHands.deposit{value: 1 ether}();

        // ! Alice enters and  withdraws with 50% penalty. Bob is not in the system, he should not be able to get reward later
        vm.startPrank(ALICE);
        strongHands.deposit{value: 1 ether}();
        strongHands.withdraw();
        vm.stopPrank();

        // ! Bob enters
        vm.startPrank(BOB);
        strongHands.deposit{value: 1 ether}();
        strongHands.claimDividends();
        vm.stopPrank();

        // ! Check Bob
        (uint256 balanceBobAfter,, uint256 timestampBobAfter, uint256 lastDividendPointsBobAfter) =
            strongHands.users(BOB);
        assertEq(balanceBobAfter, 1 ether);
        assertEq(timestampBobAfter, block.timestamp);
        assertEq(lastDividendPointsBobAfter, 1 ether); // 0.5 when bob was in system, and 0.5 when he wasn't in system, only Charlie was

        // ! Check StrongHands
        assertEq(strongHands.totalStaked(), 2 ether); // Charlie 1 + Bob 1
        assertEq(strongHands.unclaimedDividends(), 0.5 ether); // Charlie didn't claim his
        assertEq(strongHands.totalDividendPoints(), 1 ether); // 0.5 + 0.5
    }

    ////////////////////////////////
    // * calculatePenalty() Tests //
    ////////////////////////////////
    function test_calculatePenalty_ZeroPenalty() public depositWith(BOB, 1 ether) {
        skip(LOCK_PERIOD);
        uint256 penalty = strongHands.calculatePenalty(BOB);
        assertEq(penalty, 0);

        skip(LOCK_PERIOD);
        penalty = strongHands.calculatePenalty(BOB);
        assertEq(penalty, 0);
    }

    function test_calculatePenalty() public depositWith(BOB, 1 ether) {
        uint256 maxPenalty = strongHands.calculatePenalty(BOB);
        assertEq(maxPenalty, 0.5 ether);
    }
}
