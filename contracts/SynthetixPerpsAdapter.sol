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


contract SynthetixPerpsAdapter {
    using DecimalMath for uint256;
    using SignedDecimalMath for int256;

    struct SNXPerpsV2PoolHedgerParameters {
        uint targetLeverage;
        uint maximumFundingRate; // the absolute maximum funding rate per delta that the futures pool hedger is willing to pay.
        uint deltaThreshold; // Bypass interaction delay if delta is outside of a certain range.
        uint marketDepthBuffer; // percentage buffer. toBN(1.1) -> 10% buffer.
        uint priceDeltaBuffer; // percentage buffer. toBN(1.1) -> 10% buffer.
        uint worstStableRate; // the worst exchange rate the hedger is willing to accept for a swap, toBN('1.1')
        uint maxOrderCap; // the maxmimum number of deltas that can be hedged in a single order
    }

    bytes32 constant FUTURES_SETTINGS_CONTRACT = bytes32("PerpsV2MarketSettings");

    IAddressResolver public addressResolver;
    IPerpsV2MarketConsolidated public perpsMarket;
    BaseExchangeAdapter public exchangeAdapter;
    IERC20 public quoteAsset;
    IERC20 public baseAsset;
    SNXPerpsV2PoolHedgerParameters public futuresPoolHedgerParams;

    error PerpMarketReturnedInvalid();
    error IncorrectShortSize(int256 size);

    constructor(
        IPerpsV2MarketConsolidated _perpsMarket,
        IAddressResolver _addressResolver,
        IERC20 _quoteAsset,
        IERC20 _baseAsset,
        SNXPerpsV2PoolHedgerParameters memory _futuresPoolHedgerParams
    ) {
        perpsMarket = _perpsMarket;
        addressResolver = _addressResolver;
        quoteAsset = _quoteAsset;
        baseAsset = _baseAsset;
        futuresPoolHedgerParams = _futuresPoolHedgerParams;
        quoteAsset.approve(address(_perpsMarket), type(uint256).max);
        baseAsset.approve(address(_perpsMarket), type(uint256).max);
    }

    function _shortPerps(uint256 spotPrice, int256 size) internal {
        // size should be less than 0 for shorting perps
        if (size > 0) revert IncorrectShortSize(size);

        uint256 margin = getCurrentPositionMargin();
        _updateCollateral(spotPrice, margin, size);
        uint256 desiredFillPrice = spotPrice.divideDecimal(futuresPoolHedgerParams.priceDeltaBuffer);
        perpsMarket.submitOffchainDelayedOrder(size, desiredFillPrice);
    }

    /// @notice remaining margin is inclusive of pnl and margin
    function getCurrentPositionMargin() public view returns (uint) {
        (uint margin, bool invalid) = perpsMarket.remainingMargin(address(this));

        if (invalid) {
            revert PerpMarketReturnedInvalid();
        }

        return margin;
    }

    function getCurrentPositions() public view returns (int) {
        IPerpsV2MarketConsolidated.Position memory pos = perpsMarket.positions(address(this));
        return pos.size;
    }

    function _updateCollateral(uint256 spotPrice, uint256 currentCollateral, int256 size) internal {
        uint256 desiredCollateral = Math.abs(size).multiplyDecimal(spotPrice).divideDecimal(
            futuresPoolHedgerParams.targetLeverage
        );
        uint minMargin = _getFuturesMarketSettings().minInitialMargin();
        // minimum margin requirement

        if (desiredCollateral < minMargin && getCurrentPositions() != 0) {
            desiredCollateral = minMargin;
        }

        perpsMarket.transferMargin(int(desiredCollateral) - int(currentCollateral));
    }

    function _getFuturesMarketSettings() internal view returns (IPerpsV2MarketSettings) {
        return IPerpsV2MarketSettings(addressResolver.getAddress(FUTURES_SETTINGS_CONTRACT));
    }
}
