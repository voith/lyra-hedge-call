// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {OptionMarket} from "@lyrafinance/protocol/contracts/OptionMarket.sol";
import {ILyraRegistry} from "@lyrafinance/protocol/contracts/interfaces/ILyraRegistry.sol";
import {IPerpsV2MarketConsolidated} from "@lyrafinance/protocol/contracts/interfaces/perpsV2/IPerpsV2MarketConsolidated.sol";
import {IAddressResolver} from "@lyrafinance/protocol/contracts/interfaces/IAddressResolver.sol";
import {BaseExchangeAdapter} from "@lyrafinance/protocol/contracts/BaseExchangeAdapter.sol";
import {IERC20} from "openzeppelin-contracts-4.4.1/token/ERC20/IERC20.sol";
import {OptionToken} from "@lyrafinance/protocol/contracts/OptionToken.sol";
import {SignedDecimalMath} from "@lyrafinance/protocol/contracts/synthetix/SignedDecimalMath.sol";
import "forge-std/console.sol";

import {SynthetixPerpsAdapter} from "./SynthetixPerpsAdapter.sol";
import {LyraOptionsAdapter} from "./LyraOptionsAdapter.sol";

/// @title Lyra SNX Hedge Strategy
/// @author Voith
/// @notice buys options on lyra and hedges the call delta by shorting perps on snx.
contract LyraSNXHedgeStrategy is LyraOptionsAdapter, SynthetixPerpsAdapter {
    using SignedDecimalMath for int256;
    /// @notice address of QuoteAsset(USDC normally).
    IERC20 public quoteAsset;
    // @notice address of BaseAsset(sUSD normally).
    IERC20 public baseAsset;
    /// @notice address of Lyras OptionToken
    OptionToken public optionToken;

    /// @dev Initialize the contract.
    function initialize(
        ILyraRegistry _lyraRegistry,
        OptionMarket _optionMarket,
        OptionToken _optionToken,
        IPerpsV2MarketConsolidated _perpsMarket,
        IAddressResolver _addressResolver,
        IERC20 _quoteAsset,
        IERC20 _baseAsset,
        SynthetixPerpsAdapter.SNXPerpsParameters memory _snxPerpsParams
    ) internal {
        quoteAsset = _quoteAsset;
        baseAsset = _baseAsset;
        optionToken = _optionToken;
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
        _reHedgeDelta();
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

    /// @dev calculates the net call delta for all the open option positions
    function _expectedSizeDelta() internal view returns (int256) {
        int256 _totalSizeDelta = 0;
        // It seems like Lyra only maintains active positions. Positions in any other state are burnt.
        // So there's no need to check if the position is active.
        OptionToken.OptionPosition[] memory optionTokens = optionToken.getOwnerPositions(address(this));
        uint256 numberOfOptions = optionTokens.length;
        for (uint i = 0; i < numberOfOptions; i++) {
            _totalSizeDelta = getDelta(optionTokens[i].strikeId).multiplyDecimal(int(optionTokens[i].amount));
        }
        return _totalSizeDelta * int256(-1);
    }

    /// @dev fetches the spot price for the underlying asset
    /// All rates are denominated in terms of quoteAsset.
    function _getSpotPrice() internal view override returns (uint256) {
        return exchangeAdapter.getSpotPriceForMarket(address(optionMarket), BaseExchangeAdapter.PriceType.REFERENCE);
    }
}
