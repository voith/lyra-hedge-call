// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {OptionMarket} from "@lyrafinance/protocol/contracts/OptionMarket.sol";
import {ILyraRegistry} from "@lyrafinance/protocol/contracts/interfaces/ILyraRegistry.sol";
import {BlackScholes} from "@lyrafinance/protocol/contracts/libraries/BlackScholes.sol";
import {IAddressResolver} from "@lyrafinance/protocol/contracts/interfaces/IAddressResolver.sol";
import {IERC20} from "openzeppelin-contracts-4.4.1/token/ERC20/IERC20.sol";
import {BaseExchangeAdapter} from "@lyrafinance/protocol/contracts/BaseExchangeAdapter.sol";
import {DecimalMath} from "@lyrafinance/protocol/contracts/synthetix/DecimalMath.sol";

contract LyraOptionsAdapter {
    using DecimalMath for uint;
    ILyraRegistry public lyraRegistry;
    bytes32 private constant SNX_ADAPTER = "SYNTHETIX_ADAPTER";
    OptionMarket optionMarket;
    BaseExchangeAdapter public exchangeAdapter;

    function initialize(ILyraRegistry _lyraRegistry, OptionMarket _optionMarket) internal {
        optionMarket = _optionMarket;
        lyraRegistry = _lyraRegistry;
        exchangeAdapter = BaseExchangeAdapter(lyraRegistry.getGlobalAddress(SNX_ADAPTER));
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

    function getDelta(uint strikeId) public view returns (int callDelta) {
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
}
