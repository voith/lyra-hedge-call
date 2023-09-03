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

/// @title Synthetix Perpetual Futures Adapter
/// @author Voith
/// @notice contracts that helps with buying perps on synthetix and helps maintain healthy margins for positions
/// @dev credits: This contract is inspired by Lyra's `SNXPerpsV2PoolHedger` contract. (https://github.com/lyra-finance/lyra-protocol/blob/master/contracts/SNXPerpsV2PoolHedger.sol)
abstract contract SynthetixPerpsAdapter {
    using DecimalMath for uint256;
    using SignedDecimalMath for int256;

    struct SNXPerpsParameters {
        // leverage for positions opened. Choose a safe vale like 1.1 to not get liquidated.
        uint256 targetLeverage;
        // percentage buffer.toBN(1.1) -> 10% buffer.
        uint256 priceDeltaBuffer;
    }

    bytes32 constant FUTURES_SETTINGS_CONTRACT = bytes32("PerpsV2MarketSettings");

    /// @notice address of Synthetix AddressResolver.
    IAddressResolver public addressResolver;
    /// @notice address of Synthetix PerpsV2 Market.
    IPerpsV2MarketConsolidated public perpsMarket;
    /// @notice parameters for opening perps on snx.
    SNXPerpsParameters public snxPerpsParams;

    /// @notice thrown when perpsMarket returns an invalid result.
    error PerpMarketReturnedInvalid();
    /// @notice thrown when a new order is placed without executing or deleting the old order.
    error PendingOrderDeltaError(int256 pendingDelta);

    /// @dev Initialize the contract.
    function initialize(
        IPerpsV2MarketConsolidated _perpsMarket,
        IAddressResolver _addressResolver,
        SNXPerpsParameters memory _snxPerpsParams
    ) internal {
        perpsMarket = _perpsMarket;
        addressResolver = _addressResolver;
        snxPerpsParams = _snxPerpsParams;
    }

    /// @notice returns remaining margin which is inclusive of pnl and margin
    function getCurrentPositionMargin() public view returns (uint256) {
        (uint margin, bool invalid) = perpsMarket.remainingMargin(address(this));
        if (invalid) revert PerpMarketReturnedInvalid();
        return margin;
    }

    /// @notice returns the current size of the open positions on synthetix
    function getCurrentPerpsAmount() public view returns (int256) {
        IPerpsV2MarketConsolidated.Position memory pos = perpsMarket.positions(address(this));
        return pos.size;
    }

    /// @notice calculates current leverage for the open position on synthetix
    function currentLeverage() external view returns (int leverage) {
        uint256 price = _getSpotPrice();
        IPerpsV2MarketConsolidated.Position memory position = perpsMarket.positions(address(this));
        (uint remainingMargin_, ) = perpsMarket.remainingMargin(address(this));
        if (remainingMargin_ == 0) {
            return int(0);
        }
        return int(position.size).multiplyDecimal(int(price)).divideDecimal(int(remainingMargin_));
    }

    /// @dev submits a delayed order on snx for opening perps of given size.
    /// It also adjust the collateral needed for opening the position.
    function _submitOrderForPerps(uint256 spotPrice, int256 size) internal {
        // Dont submit if there is a pending order
        _checkPendingOrder();
        _addCollateral(spotPrice, size);
        uint256 desiredFillPrice = size > 0
            ? spotPrice.multiplyDecimal(snxPerpsParams.priceDeltaBuffer)
            : spotPrice.divideDecimal(snxPerpsParams.priceDeltaBuffer);
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

    /// @dev fetches the spot price for the market.
    /// All rates are denominated in terms of quoteAsset.
    function _getSpotPrice() internal view virtual returns (uint256);

    /// @dev adds margin to the market for opening perps
    function _addCollateral(uint256 spotPrice, int256 size) internal {
        int256 newSize = size + getCurrentPerpsAmount();
        uint256 desiredCollateral = Math.abs(newSize).multiplyDecimal(spotPrice).divideDecimal(
            snxPerpsParams.targetLeverage
        );
        uint256 currentCollateral = getCurrentPositionMargin();
        uint256 minMargin = _getFuturesMarketSettings().minInitialMargin();
        // minimum margin requirement
        if (desiredCollateral < minMargin && getCurrentPerpsAmount() != 0) {
            desiredCollateral = minMargin;
        }

        perpsMarket.transferMargin(int256(desiredCollateral) - int256(currentCollateral));
    }

    // @dev returns the futuresMarketSettings
    function _getFuturesMarketSettings() internal view returns (IPerpsV2MarketSettings) {
        return IPerpsV2MarketSettings(addressResolver.getAddress(FUTURES_SETTINGS_CONTRACT));
    }
}
