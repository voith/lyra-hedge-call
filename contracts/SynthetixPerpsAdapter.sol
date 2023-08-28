// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IPerpsV2MarketConsolidated} from "@lyrafinance/protocol/contracts/interfaces/perpsV2/IPerpsV2MarketConsolidated.sol";
import {ICurve} from "@lyrafinance/protocol/contracts/interfaces/ICurve.sol";
import {BaseExchangeAdapter} from "@lyrafinance/protocol/contracts/BaseExchangeAdapter.sol";
import {OptionMarket} from "@lyrafinance/protocol/contracts/OptionMarket.sol";
import {IAddressResolver} from "@lyrafinance/protocol/contracts/interfaces/IAddressResolver.sol";
import {IPerpsV2MarketSettings} from "@lyrafinance/protocol/contracts/interfaces/perpsV2/IPerpsV2MarketSettings.sol";
import {IERC20} from "openzeppelin-contracts-4.4.1/token/ERC20/IERC20.sol";
import {DecimalMath} from "@lyrafinance/protocol/contracts/synthetix/DecimalMath.sol";
import {SignedDecimalMath} from "@lyrafinance/protocol/contracts/synthetix/SignedDecimalMath.sol";
import {SafeCast} from "openzeppelin-contracts-4.4.1/utils/math/SafeCast.sol";
import {Math} from "@lyrafinance/protocol/contracts/libraries/Math.sol";

import {ReentrancyGuard} from "openzeppelin-contracts-4.4.1/security/ReentrancyGuard.sol";

abstract contract SynthetixPerpsAdapter is ReentrancyGuard {
    using DecimalMath for uint256;
    using SignedDecimalMath for int256;

    // TODO: remove unused vars
    struct SNXPerpsV2PoolHedgerParameters {
        uint targetLeverage;
        uint priceDeltaBuffer; // percentage buffer. toBN(1.1) -> 10% buffer.
    }

    bytes32 constant FUTURES_SETTINGS_CONTRACT = bytes32("PerpsV2MarketSettings");

    IAddressResolver public addressResolver;
    IPerpsV2MarketConsolidated public perpsMarket;
    SNXPerpsV2PoolHedgerParameters public futuresPoolHedgerParams;

    error PerpMarketReturnedInvalid();
    error IncorrectShortSize(int256 size);
    error PendingOrderDeltaError(int256 pendingDelta);

    constructor(
        IPerpsV2MarketConsolidated _perpsMarket,
        IAddressResolver _addressResolver,
        SNXPerpsV2PoolHedgerParameters memory _futuresPoolHedgerParams
    ) {
        perpsMarket = _perpsMarket;
        addressResolver = _addressResolver;
        futuresPoolHedgerParams = _futuresPoolHedgerParams;
    }

    /**
     * @notice Updates the collateral held in the short to prevent liquidations and return excess collateral
     */
    function updateCollateral() external payable nonReentrant {
        // Dont update if there is a pending order
        _checkPendingOrder();

        uint spotPrice = _getSpotPrice();

        uint margin = getCurrentPositionMargin();

        _updateCollateral(spotPrice, margin, getCurrentPerpsAmount());
    }

    function _submitOrderForPerps(uint256 spotPrice, int256 size) internal {
        uint256 margin = getCurrentPositionMargin();
        _updateCollateral(spotPrice, margin, size);
        uint256 desiredFillPrice = size > 0
            ? spotPrice.multiplyDecimal(futuresPoolHedgerParams.priceDeltaBuffer)
            : spotPrice.divideDecimal(futuresPoolHedgerParams.priceDeltaBuffer);
        perpsMarket.submitOffchainDelayedOrder(size, desiredFillPrice);
    }

    /// @dev checks if there's a pending order and reverts if there is
    function _checkPendingOrder() internal view {
        IPerpsV2MarketConsolidated.DelayedOrder memory delayedOrder = perpsMarket.delayedOrders(address(this));
        int256 pendingOrderDelta = delayedOrder.sizeDelta;
        if (pendingOrderDelta != 0) {
            revert PendingOrderDeltaError(pendingOrderDelta);
        }
    }

    function _getSpotPrice() internal view virtual returns (uint256);

    /// @notice remaining margin is inclusive of pnl and margin
    function getCurrentPositionMargin() public view returns (uint256) {
        (uint margin, bool invalid) = perpsMarket.remainingMargin(address(this));

        if (invalid) {
            revert PerpMarketReturnedInvalid();
        }

        return margin;
    }

    function getCurrentPerpsAmount() public view returns (int256) {
        IPerpsV2MarketConsolidated.Position memory pos = perpsMarket.positions(address(this));
        return pos.size;
    }

    function _updateCollateral(uint256 spotPrice, uint256 currentCollateral, int256 size) internal {
        uint256 desiredCollateral = Math.abs(size).multiplyDecimal(spotPrice).divideDecimal(
            futuresPoolHedgerParams.targetLeverage
        );
        uint minMargin = _getFuturesMarketSettings().minInitialMargin();
        // minimum margin requirement

        if (desiredCollateral < minMargin && getCurrentPerpsAmount() != 0) {
            desiredCollateral = minMargin;
        }

        perpsMarket.transferMargin(int(desiredCollateral) - int(currentCollateral));
    }

    function _getFuturesMarketSettings() internal view returns (IPerpsV2MarketSettings) {
        return IPerpsV2MarketSettings(addressResolver.getAddress(FUTURES_SETTINGS_CONTRACT));
    }
}
