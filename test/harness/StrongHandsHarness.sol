// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {StrongHands, IWrappedTokenGatewayV3, IPool, IERC20} from "../../src/StrongHands.sol";

contract StrongHandsHarness is StrongHands {
    constructor(uint256 _lockPeriod, IWrappedTokenGatewayV3 _wrappedTokenGatewayV3, IPool _pool, IERC20 _aEthWeth)
        StrongHands(_lockPeriod, _wrappedTokenGatewayV3, _pool, _aEthWeth)
    {}

    // Helper to get user's dividends owing for testing
    function harnessDividendsOwing(address userAddr) external view returns (uint256) {
        return _dividendsOwing(users[userAddr]);
    }
}
