// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LyraAdapter} from "@lyrafinance/protocol/contracts/periphery/LyraAdapter.sol";
import {OptionMarket} from "@lyrafinance/protocol/contracts/OptionMarket.sol";
import {ISynthetixAdapter} from "@lyrafinance/protocol/contracts/interfaces/ISynthetixAdapter.sol";
import {ICurve} from "@lyrafinance/protocol/contracts/interfaces/ICurve.sol";
import {ILyraRegistry} from "@lyrafinance/protocol/contracts/interfaces/ILyraRegistry.sol";
import {IPerpsV2MarketConsolidated} from "@lyrafinance/protocol/contracts/interfaces/perpsV2/IPerpsV2MarketConsolidated.sol";
import {IAddressResolver} from "@lyrafinance/protocol/contracts/interfaces/IAddressResolver.sol";
import {BaseExchangeAdapter} from "@lyrafinance/protocol/contracts/BaseExchangeAdapter.sol";
import {BasicFeeCounter} from "@lyrafinance/protocol/contracts/periphery/BasicFeeCounter.sol";
import {BlackScholes} from "@lyrafinance/protocol/contracts/libraries/BlackScholes.sol";
import {DecimalMath} from "@lyrafinance/protocol/contracts/synthetix/DecimalMath.sol";
import {IERC20} from "openzeppelin-contracts-4.4.1/token/ERC20/IERC20.sol";
import {SynthetixPerpsAdapter} from "./SynthetixPerpsAdapter.sol";

import "forge-std/console.sol";

contract LyraSNXHedger is SynthetixPerpsAdapter {
    using DecimalMath for uint;
    ILyraRegistry public lyraRegistry;
    bytes32 private constant SNX_ADAPTER = "SYNTHETIX_ADAPTER";
    OptionMarket optionMarket;

    constructor(
        ILyraRegistry _lyraRegistry,
        OptionMarket _optionMarket,
        IPerpsV2MarketConsolidated _perpsMarket,
        IAddressResolver _addressResolver,
        IERC20 _quoteAsset,
        IERC20 _baseAsset,
        SynthetixPerpsAdapter.SNXPerpsV2PoolHedgerParameters memory _futuresPoolHedgerParams
    ) SynthetixPerpsAdapter(_perpsMarket, _addressResolver, _quoteAsset, _baseAsset, _futuresPoolHedgerParams) {
        optionMarket = _optionMarket;
        lyraRegistry = _lyraRegistry;
        exchangeAdapter = BaseExchangeAdapter(lyraRegistry.getGlobalAddress(SNX_ADAPTER));
        quoteAsset.approve(address(_optionMarket), type(uint256).max);
        baseAsset.approve(address(_optionMarket), type(uint256).max);
    }

    function addQuoteAsset(uint256 amount) external {
        quoteAsset.transferFrom(msg.sender, address(this), amount);
    }

    function buyHedgedCall(uint256 strikeId, uint256 amount) external {
        _buyCall(strikeId, amount);
        _hedgeDelta(int(amount) * _getDeltas(strikeId) * int(-1));
    }

    function _hedgeDelta(int256 sizeDelta) internal {
        uint256 spotPrice = exchangeAdapter.getSpotPriceForMarket(
            address(optionMarket),
            BaseExchangeAdapter.PriceType.REFERENCE
        );
        _shortPerps(spotPrice, sizeDelta);
    }

    function _buyCall(uint strikeId, uint amount) internal {
        OptionMarket.TradeInputParameters memory params = OptionMarket.TradeInputParameters({
            strikeId: strikeId,
            positionId: 0,
            optionType: OptionMarket.OptionType.LONG_CALL,
            amount: amount,
            setCollateralTo: 0,
            iterations: 1,
            minTotalCost: 0,
            maxTotalCost: type(uint256).max,
            referrer: address(0)
        });
        optionMarket.openPosition(params);
    }

    function _getDeltas(uint strikeId) internal view returns (int callDelta) {
        BlackScholes.BlackScholesInputs memory bsInput = _getBsInput(strikeId);
        (callDelta, ) = BlackScholes.delta(bsInput);
    }

    /// @dev format all strike related params before input into BlackScholes
    function _getBsInput(uint strikeId) internal view returns (BlackScholes.BlackScholesInputs memory bsInput) {
        (OptionMarket.Strike memory strike, OptionMarket.OptionBoard memory board) = optionMarket.getStrikeAndBoard(
            strikeId
        );
        bsInput = BlackScholes.BlackScholesInputs({
            timeToExpirySec: board.expiry - block.timestamp,
            volatilityDecimal: board.iv.multiplyDecimal(strike.skew),
            spotDecimal: exchangeAdapter.getSpotPriceForMarket(
                address(optionMarket),
                BaseExchangeAdapter.PriceType.REFERENCE
            ),
            strikePriceDecimal: strike.strikePrice,
            rateDecimal: exchangeAdapter.rateAndCarry(address(optionMarket))
        });
    }

    receive() external payable {}
}
