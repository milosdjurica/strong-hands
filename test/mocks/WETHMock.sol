// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IWETH} from "@aave/v3-origin/contracts/helpers/interfaces/IWETH.sol";

contract WETHMock is IWETH {
    function deposit() external payable override {}

    function withdraw(uint256) external override {}

    function approve(address guy, uint256 wad) external override returns (bool) {}

    function transferFrom(address src, address dst, uint256 wad) external override returns (bool) {}
}
