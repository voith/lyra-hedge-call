# LyraOptionsAdapter
[Git Source](https://github.com/voith/lyra-hedge-call/blob/6d8d03993f954009976ed0c983a934150d408004/contracts/LyraOptionsAdapter.sol)

**Author:**
Voith

contains logic for buying a call option and also for calculating its delta.


## State Variables
### SNX_ADAPTER

```solidity
bytes32 private constant SNX_ADAPTER = "SYNTHETIX_ADAPTER";
```


### lyraRegistry
*address of Lyra's LyraRegistry contract*


```solidity
ILyraRegistry lyraRegistry;
```


### optionMarket
*address of Lyra's OptionMarket contract.*


```solidity
OptionMarket optionMarket;
```


### exchangeAdapter
*address of Lyra's  BaseExchangeAdapter contract*


```solidity
BaseExchangeAdapter public exchangeAdapter;
```


## Functions
### initialize

*Initialize the contract.*


```solidity
function initialize(ILyraRegistry _lyraRegistry, OptionMarket _optionMarket) internal;
```

### getDelta

Returns current spot deltas for a given strikeId (using BlackScholes and spot volatilities).


```solidity
function getDelta(uint256 strikeId) public view returns (int256 callDelta);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strikeId`|`uint256`||


### _buyCall

*buys a call option from lyra for a given strikeId and amount.*


```solidity
function _buyCall(uint256 strikeId, uint256 amount) internal returns (OptionMarket.Result memory result);
```

### _getBsInput

*format all strike related params before input into BlackScholes*


```solidity
function _getBsInput(uint256 strikeId) internal view returns (BlackScholes.BlackScholesInputs memory bsInput);
```

