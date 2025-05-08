// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IPool} from "@aave/v3-origin/contracts/interfaces/IPool.sol";
import {DataTypes} from "@aave/v3-origin/contracts/protocol/libraries/types/DataTypes.sol";
import {IPoolAddressesProvider} from "@aave/v3-origin/contracts/interfaces/IPoolAddressesProvider.sol";

contract PoolMock is IPool {
    function mintUnbacked(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external override {}

    function backUnbacked(address asset, uint256 amount, uint256 fee) external override returns (uint256) {}

    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external override {}

    function supplyWithPermit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external override {}

    function withdraw(address asset, uint256 amount, address to) external override returns (uint256) {}

    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)
        external
        override
    {}

    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf)
        external
        override
        returns (uint256)
    {}

    function repayWithPermit(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external override returns (uint256) {}

    function repayWithATokens(address asset, uint256 amount, uint256 interestRateMode)
        external
        override
        returns (uint256)
    {}

    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external override {}

    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external override {}

    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external override {}

    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external override {}

    function getUserAccountData(address user)
        external
        view
        override
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {}

    function initReserve(
        address asset,
        address aTokenAddress,
        address variableDebtAddress,
        address interestRateStrategyAddress
    ) external override {}

    function dropReserve(address asset) external override {}

    function setReserveInterestRateStrategyAddress(address asset, address rateStrategyAddress) external override {}

    function syncIndexesState(address asset) external override {}

    function syncRatesState(address asset) external override {}

    function setConfiguration(address asset, DataTypes.ReserveConfigurationMap calldata configuration)
        external
        override
    {}

    function getConfiguration(address asset)
        external
        view
        override
        returns (DataTypes.ReserveConfigurationMap memory)
    {}

    function getUserConfiguration(address user)
        external
        view
        override
        returns (DataTypes.UserConfigurationMap memory)
    {}

    function getReserveNormalizedIncome(address asset) external view override returns (uint256) {}

    function getReserveNormalizedVariableDebt(address asset) external view override returns (uint256) {}

    function getReserveData(address asset) external view override returns (DataTypes.ReserveDataLegacy memory) {}

    function getVirtualUnderlyingBalance(address asset) external view override returns (uint128) {}

    function finalizeTransfer(
        address asset,
        address from,
        address to,
        uint256 amount,
        uint256 balanceFromBefore,
        uint256 balanceToBefore
    ) external override {}

    function getReservesList() external view override returns (address[] memory) {}

    function getReservesCount() external view override returns (uint256) {}

    function getReserveAddressById(uint16 id) external view override returns (address) {}

    function ADDRESSES_PROVIDER() external view override returns (IPoolAddressesProvider) {}

    function updateBridgeProtocolFee(uint256 bridgeProtocolFee) external override {}

    function updateFlashloanPremiums(uint128 flashLoanPremiumTotal, uint128 flashLoanPremiumToProtocol)
        external
        override
    {}

    function configureEModeCategory(uint8 id, DataTypes.EModeCategoryBaseConfiguration memory config)
        external
        override
    {}

    function configureEModeCategoryCollateralBitmap(uint8 id, uint128 collateralBitmap) external override {}

    function configureEModeCategoryBorrowableBitmap(uint8 id, uint128 borrowableBitmap) external override {}

    function getEModeCategoryData(uint8 id) external view override returns (DataTypes.EModeCategoryLegacy memory) {}

    function getEModeCategoryLabel(uint8 id) external view override returns (string memory) {}

    function getEModeCategoryCollateralConfig(uint8 id)
        external
        view
        override
        returns (DataTypes.CollateralConfig memory)
    {}

    function getEModeCategoryCollateralBitmap(uint8 id) external view override returns (uint128) {}

    function getEModeCategoryBorrowableBitmap(uint8 id) external view override returns (uint128) {}

    function setUserEMode(uint8 categoryId) external override {}

    function getUserEMode(address user) external view override returns (uint256) {}

    function resetIsolationModeTotalDebt(address asset) external override {}

    function setLiquidationGracePeriod(address asset, uint40 until) external override {}

    function getLiquidationGracePeriod(address asset) external view override returns (uint40) {}

    function FLASHLOAN_PREMIUM_TOTAL() external view override returns (uint128) {}

    function BRIDGE_PROTOCOL_FEE() external view override returns (uint256) {}

    function FLASHLOAN_PREMIUM_TO_PROTOCOL() external view override returns (uint128) {}

    function MAX_NUMBER_RESERVES() external view override returns (uint16) {}

    function mintToTreasury(address[] calldata assets) external override {}

    function rescueTokens(address token, address to, uint256 amount) external override {}

    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external override {}

    function eliminateReserveDeficit(address asset, uint256 amount) external override {}

    function getReserveDeficit(address asset) external view override returns (uint256) {}

    function getReserveAToken(address asset) external view override returns (address) {}

    function getReserveVariableDebtToken(address asset) external view override returns (address) {}

    function getFlashLoanLogic() external view override returns (address) {}

    function getBorrowLogic() external view override returns (address) {}

    function getBridgeLogic() external view override returns (address) {}

    function getEModeLogic() external view override returns (address) {}

    function getLiquidationLogic() external view override returns (address) {}

    function getPoolLogic() external view override returns (address) {}

    function getSupplyLogic() external view override returns (address) {}
}
