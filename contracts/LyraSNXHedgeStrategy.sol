// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {OptionMarket} from "@lyrafinance/protocol/contracts/OptionMarket.sol";
import {ILyraRegistry} from "@lyrafinance/protocol/contracts/interfaces/ILyraRegistry.sol";
import {IPerpsV2MarketConsolidated} from "@lyrafinance/protocol/contracts/interfaces/perpsV2/IPerpsV2MarketConsolidated.sol";
import {IAddressResolver} from "@lyrafinance/protocol/contracts/interfaces/IAddressResolver.sol";
import {BaseExchangeAdapter} from "@lyrafinance/protocol/contracts/BaseExchangeAdapter.sol";
import {IERC20} from "openzeppelin-contracts-4.4.1/token/ERC20/IERC20.sol";

import {SynthetixPerpsAdapter} from "./SynthetixPerpsAdapter.sol";
import {LyraOptionsAdapter} from "./LyraOptionsAdapter.sol";

/// @title Lyra Snx Hedger
/// @author Voith
/// @notice buys options on lyra and hedges the call delta by shorting perps on snx.
contract LyraSNXHedgeStrategy is LyraOptionsAdapter, SynthetixPerpsAdapter {
    /// @notice address of QuoteAsset(USDC normally).
    IERC20 public quoteAsset;
    // @notice address of BaseAsset(sUSD normally).
    IERC20 public baseAsset;
    /// @dev array to keep track of strikes for which positons are opened and hedged.
    uint256[] private activeStrikeIds;
    /// @dev mapping of StrikeID to Size of the option opened
    mapping(uint256 => uint256) strikeAmounts;

    /// @dev Initialize the contract.
    function initialize(
        ILyraRegistry _lyraRegistry,
        OptionMarket _optionMarket,
        IPerpsV2MarketConsolidated _perpsMarket,
        IAddressResolver _addressResolver,
        IERC20 _quoteAsset,
        IERC20 _baseAsset,
        SynthetixPerpsAdapter.SNXPerpsParameters memory _snxPerpsParams
    ) internal {
        quoteAsset = _quoteAsset;
        baseAsset = _baseAsset;
        quoteAsset.approve(address(_perpsMarket), type(uint256).max);
        baseAsset.approve(address(_perpsMarket), type(uint256).max);
        quoteAsset.approve(address(_optionMarket), type(uint256).max);
        baseAsset.approve(address(_optionMarket), type(uint256).max);
        super.initialize(_perpsMarket, _addressResolver, _snxPerpsParams);
        super.initialize(_lyraRegistry, _optionMarket);
    }

    /// @dev buys a call for a given strikeId and amount and the hedges the delta of the option by selling perps on snx.
    function _buyHedgedCall(uint256 strikeId, uint256 amount) internal {
        _buyCall(strikeId, amount);
        _hedgeCallDelta(int(amount) * getDelta(strikeId) * int(-1));
        activeStrikeIds.push(strikeId);
        strikeAmounts[strikeId] += amount;
    }

    /// @dev re-calculates the net delta of all the open positions and re-balances the hedged delta
    /// by buying/selling perps on snx.
    function _reHedgeDelta() internal {
        int256 expectedSizeDelta = _expectedSizeDelta();
        int256 currentSizeDelta = getCurrentPerpsAmount();
        if (expectedSizeDelta == currentSizeDelta) return;
        _hedgeCallDelta(expectedSizeDelta - currentSizeDelta);
    }

    /// @dev submits a delayed order of given sizeDelta on snx.
    /// It also adjust the margin needed for opening the position.
    function _hedgeCallDelta(int256 sizeDelta) internal {
        uint256 spotPrice = exchangeAdapter.getSpotPriceForMarket(
            address(optionMarket),
            BaseExchangeAdapter.PriceType.REFERENCE
        );
        _submitOrderForPerps(spotPrice, sizeDelta);
    }

    /// @dev calculates the net call for all the open option positions
    /// This is an ugly solution to calculate net delta by looping over all the active Strikes.
    /// However, the number strikes open at given point of time are a small number and hence this
    /// function should not run out of gas.
    function _expectedSizeDelta() internal view returns (int256) {
        int256 _totalSizeDelta = 0;
        uint256 activeStrikeLength = activeStrikeIds.length;
        for (uint256 i = 0; i < activeStrikeLength; i++) {
            uint256 _strikeId = activeStrikeIds[i];
            _totalSizeDelta += (getDelta(_strikeId) * int(strikeAmounts[_strikeId]));
        }
        return _totalSizeDelta * int256(-1);
    }

    /// @dev fetches the spot price for the underlying asset
    /// All rates are denominated in terms of quoteAsset.
    function _getSpotPrice() internal view override returns (uint256) {
        return exchangeAdapter.getSpotPriceForMarket(address(optionMarket), BaseExchangeAdapter.PriceType.REFERENCE);
    }
}
