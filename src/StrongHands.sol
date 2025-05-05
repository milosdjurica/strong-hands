// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract StrongHands {
    uint256 immutable i_lockPeriod;

    constructor(uint256 _lockPeriod) {
        i_lockPeriod = _lockPeriod;
    }
}
