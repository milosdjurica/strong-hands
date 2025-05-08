// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IWrappedTokenGatewayV3} from "@aave/v3-origin/contracts/helpers/interfaces/IWrappedTokenGatewayV3.sol";
import {IWETH} from "@aave/v3-origin/contracts/helpers/interfaces/IWETH.sol";
import {IPool} from "@aave/v3-origin/contracts/interfaces/IPool.sol";

contract WrappedTokenGatewayV3Mock is IWrappedTokenGatewayV3 {
    function WETH() external view override returns (IWETH) {}

    function POOL() external view override returns (IPool) {}

    function depositETH(address pool, address onBehalfOf, uint16 referralCode) external payable override {}

    function withdrawETH(address pool, uint256 amount, address onBehalfOf) external override {}

    function repayETH(address pool, uint256 amount, address onBehalfOf) external payable override {}

    function borrowETH(address pool, uint256 amount, uint16 referralCode) external override {}

    function withdrawETHWithPermit(
        address pool,
        uint256 amount,
        address to,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external override {}
}
