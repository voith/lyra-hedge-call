# SynthetixPerpsAdapter
[Git Source](https://github.com/voith/lyra-hedge-call/blob/cca9b2818d585390a65c6eb856ad369c2b512f4f/contracts/SynthetixPerpsAdapter.sol)

**Author:**
Voith

contracts that helps with buying perps on synthetix and helps maintain healthy margins for positions

*credits: This contract is inspired by Lyra's `SNXPerpsV2PoolHedger` contract. (https://github.com/lyra-finance/lyra-protocol/blob/master/contracts/SNXPerpsV2PoolHedger.sol)*


## State Variables
### FUTURES_SETTINGS_CONTRACT

```solidity
bytes32 constant FUTURES_SETTINGS_CONTRACT = bytes32("PerpsV2MarketSettings");
```


### addressResolver
address of Synthetix AddressResolver.


```solidity
IAddressResolver public addressResolver;
```


### perpsMarket
address of Synthetix PerpsV2 Market.


```solidity
IPerpsV2MarketConsolidated public perpsMarket;
```


### snxPerpsParams
parameters for opening perps on snx.


```solidity
SNXPerpsParameters public snxPerpsParams;
```


## Functions
### initialize

*Initialize the contract.*


```solidity
function initialize(
    IPerpsV2MarketConsolidated _perpsMarket,
    IAddressResolver _addressResolver,
    SNXPerpsParameters memory _snxPerpsParams
) internal;
```

### getCurrentPositionMargin

returns remaining margin which is inclusive of pnl and margin


```solidity
function getCurrentPositionMargin() public view returns (uint256);
```

### getCurrentPerpsAmount

returns the current size of the open positions on synthetix


```solidity
function getCurrentPerpsAmount() public view returns (int256);
```

### currentLeverage

calculates current leverage for the open position on synthetix


```solidity
function currentLeverage() external view returns (int256 leverage);
```

### _submitOrderForPerps

*submits a delayed order on snx for opening perps of given size.
It also adjust the collateral needed for opening the position.*


```solidity
function _submitOrderForPerps(uint256 spotPrice, int256 size) internal;
```

### _checkPendingOrder

*checks if there's a pending order and reverts if there is*


```solidity
function _checkPendingOrder() internal view;
```

### _getSpotPrice

*fetches the spot price for the market.
All rates are denominated in terms of quoteAsset.*


```solidity
function _getSpotPrice() internal view virtual returns (uint256);
```

### _addCollateral

*adds margin to the market for opening perps*


```solidity
function _addCollateral(uint256 spotPrice, int256 size) internal;
```

### _getFuturesMarketSettings


```solidity
function _getFuturesMarketSettings() internal view returns (IPerpsV2MarketSettings);
```

## Errors
### PerpMarketReturnedInvalid
thrown when perpsMarket returns an invalid result.


```solidity
error PerpMarketReturnedInvalid();
```

### PendingOrderDeltaError
thrown when a new order is placed without executing or deleting the old order.


```solidity
error PendingOrderDeltaError(int256 pendingDelta);
```

## Structs
### SNXPerpsParameters

```solidity
struct SNXPerpsParameters {
    uint256 targetLeverage;
    uint256 priceDeltaBuffer;
}
```

