// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {OptionMarket} from "@lyrafinance/protocol/contracts/OptionMarket.sol";
import {ILyraRegistry} from "@lyrafinance/protocol/contracts/interfaces/ILyraRegistry.sol";
import {BlackScholes} from "@lyrafinance/protocol/contracts/libraries/BlackScholes.sol";
import {IAddressResolver} from "@lyrafinance/protocol/contracts/interfaces/IAddressResolver.sol";
import {IERC20} from "openzeppelin-contracts-4.4.1/token/ERC20/IERC20.sol";
import {BaseExchangeAdapter} from "@lyrafinance/protocol/contracts/BaseExchangeAdapter.sol";
import {DecimalMath} from "@lyrafinance/protocol/contracts/synthetix/DecimalMath.sol";

/// @title Lyra Options Adapter
/// @author Voith
/// @notice contains logic for buying a call option and also for calculating its delta.
contract LyraOptionsAdapter {
    using DecimalMath for uint;

    bytes32 private constant SNX_ADAPTER = "SYNTHETIX_ADAPTER";
    /// @dev address of Lyra's LyraRegistry contract
    ILyraRegistry lyraRegistry;
    /// @dev address of Lyra's OptionMarket contract.
    OptionMarket optionMarket;
    /// @dev address of Lyra's  BaseExchangeAdapter contract
    BaseExchangeAdapter public exchangeAdapter;

    /// @dev Initialize the contract.
    function initialize(ILyraRegistry _lyraRegistry, OptionMarket _optionMarket) internal {
        optionMarket = _optionMarket;
        lyraRegistry = _lyraRegistry;
        exchangeAdapter = BaseExchangeAdapter(lyraRegistry.getGlobalAddress(SNX_ADAPTER));
    }

    /// @notice Returns current spot deltas for a given strikeId (using BlackScholes and spot volatilities).
    /// @param strikeId: Id of the strike whose delta is to be calculated.
    function getDelta(uint strikeId) public view returns (int callDelta) {
        BlackScholes.BlackScholesInputs memory bsInput = _getBsInput(strikeId);
        (callDelta, ) = BlackScholes.delta(bsInput);
    }

    /// @dev buys a call option from lyra for a given strikeId and amount.
    function _buyCall(uint strikeId, uint amount) internal returns (OptionMarket.Result memory result) {
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
        result = optionMarket.openPosition(params);
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
