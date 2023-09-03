# LyraSNXHedgeStrategy
[Git Source](https://github.com/voith/lyra-hedge-call/blob/cca9b2818d585390a65c6eb856ad369c2b512f4f/contracts/LyraSNXHedgeStrategy.sol)

**Inherits:**
[LyraOptionsAdapter](/contracts/LyraOptionsAdapter.sol/contract.LyraOptionsAdapter.md), [SynthetixPerpsAdapter](/contracts/SynthetixPerpsAdapter.sol/abstract.SynthetixPerpsAdapter.md)

**Author:**
Voith

buys options on lyra and hedges the call delta by shorting perps on snx.


## State Variables
### quoteAsset
address of QuoteAsset(USDC normally).


```solidity
IERC20 public quoteAsset;
```


### baseAsset

```solidity
IERC20 public baseAsset;
```


### optionToken
address of Lyras OptionToken


```solidity
OptionToken public optionToken;
```


## Functions
### initialize

*Initialize the contract.*


```solidity
function initialize(
    ILyraRegistry _lyraRegistry,
    OptionMarket _optionMarket,
    OptionToken _optionToken,
    IPerpsV2MarketConsolidated _perpsMarket,
    IAddressResolver _addressResolver,
    IERC20 _quoteAsset,
    IERC20 _baseAsset,
    SynthetixPerpsAdapter.SNXPerpsParameters memory _snxPerpsParams
) internal;
```

### _buyHedgedCall

*buys a call for a given strikeId and amount and the hedges the delta of the option by selling perps on snx.*


```solidity
function _buyHedgedCall(uint256 strikeId, uint256 amount) internal;
```

### _reHedgeDelta

*re-calculates the net delta of all the open positions and re-balances the hedged delta
by buying/selling perps on snx.*


```solidity
function _reHedgeDelta() internal;
```

### _expectedSizeDelta

*calculates the net call delta for all the open option positions*


```solidity
function _expectedSizeDelta() internal view returns (int256);
```

### _getSpotPrice

*fetches the spot price for the underlying asset
All rates are denominated in terms of quoteAsset.*


```solidity
function _getSpotPrice() internal view override returns (uint256);
```

