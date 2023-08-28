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


// TODO: all functions should be owner protected.
contract LyraSNXHedger is LyraOptionsAdapter, SynthetixPerpsAdapter {
    IERC20 public quoteAsset;
    IERC20 public baseAsset;
    uint256[] private activeStrikeIds;
    mapping(uint256 => uint256) strikeAmounts;

    constructor(
        ILyraRegistry _lyraRegistry,
        OptionMarket _optionMarket,
        IPerpsV2MarketConsolidated _perpsMarket,
        IAddressResolver _addressResolver,
        IERC20 _quoteAsset,
        IERC20 _baseAsset,
        SynthetixPerpsAdapter.SNXPerpsV2PoolHedgerParameters memory _futuresPoolHedgerParams
    )
        LyraOptionsAdapter(_lyraRegistry, _optionMarket)
        SynthetixPerpsAdapter(_perpsMarket, _addressResolver, _futuresPoolHedgerParams)
    {
        quoteAsset = _quoteAsset;
        baseAsset = _baseAsset;
        quoteAsset.approve(address(_perpsMarket), type(uint256).max);
        baseAsset.approve(address(_perpsMarket), type(uint256).max);
        quoteAsset.approve(address(_optionMarket), type(uint256).max);
        baseAsset.approve(address(_optionMarket), type(uint256).max);
    }

    function buyHedgedCall(uint256 strikeId, uint256 amount) external {
        _buyCall(strikeId, amount);
        _hedgeCallDelta(int(amount) * getDelta(strikeId) * int(-1));
        activeStrikeIds.push(strikeId);
        strikeAmounts[strikeId] += amount;
    }

    function reHedgeDelta() external {
        int256 expectedSizeDelta = _expectedSizeDelta();
        int256 currentSizeDelta = getCurrentPerpsAmount();
        if (expectedSizeDelta == currentSizeDelta) return;
        _hedgeCallDelta(expectedSizeDelta - currentSizeDelta);
    }

    function _hedgeCallDelta(int256 sizeDelta) internal {
        uint256 spotPrice = exchangeAdapter.getSpotPriceForMarket(
            address(optionMarket),
            BaseExchangeAdapter.PriceType.REFERENCE
        );
        _submitOrderForPerps(spotPrice, sizeDelta);
    }

    function _expectedSizeDelta() internal view returns (int256) {
        int256 _totalSizeDelta = 0;
        uint256 activeStrikeLength = activeStrikeIds.length;
        for (uint256 i = 0; i < activeStrikeLength; i++) {
            uint256 _strikeId = activeStrikeIds[i];
            _totalSizeDelta += (getDelta(_strikeId) * int(strikeAmounts[_strikeId]));
        }
        return _totalSizeDelta * int256(-1);
    }

    function _getSpotPrice() internal view override returns (uint256) {
        return exchangeAdapter.getSpotPriceForMarket(address(optionMarket), BaseExchangeAdapter.PriceType.REFERENCE);
    }

    receive() external payable {}

    function recoverFunds(IERC20 token, address recipient) external {
        token.transfer(recipient, token.balanceOf(address(this)));
    }
}
