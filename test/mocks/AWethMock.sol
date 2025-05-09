// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@aave/v3-origin/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

contract AWethMock is IERC20 {
    function totalSupply() external view override returns (uint256) {}

    function balanceOf(address account) external view override returns (uint256) {
        // mock value
        return 1 ether;
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {}

    function allowance(address owner, address spender) external view override returns (uint256) {}

    function approve(address spender, uint256 amount) external override returns (bool) {}

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {}
}
