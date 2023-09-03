# Account
[Git Source](https://github.com/voith/lyra-hedge-call/blob/6d8d03993f954009976ed0c983a934150d408004/contracts/Account.sol)

**Inherits:**
Initializable, [LyraSNXHedgeStrategy](/contracts/LyraSNXHedgeStrategy.sol/contract.LyraSNXHedgeStrategy.md), Ownable

**Author:**
Voith

account that allows users to buy on-chain derivatives and has hedging capabilities

*credits: This contract is inspired by kwenta's smart margin account. (https://github.com/Kwenta/smart-margin/blob/main/src/Account.sol)*


## Functions
### initialize

*Initialize the contract.*


```solidity
function initialize(
    address _owner,
    ILyraRegistry _lyraRegistry,
    OptionMarket _optionMarket,
    OptionToken _optionToken,
    IPerpsV2MarketConsolidated _perpsMarket,
    IAddressResolver _addressResolver,
    IERC20 _quoteAsset,
    IERC20 _baseAsset,
    SynthetixPerpsAdapter.SNXPerpsParameters memory _snxPerpsParams
) external initializer;
```

### buyHedgedCall

buys a call for a given strikeId and amount and the hedges the delta of the option by selling perps on snx.


```solidity
function buyHedgedCall(uint256 strikeId, uint256 amount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`strikeId`|`uint256`||
|`amount`|`uint256`||


### reHedgeDelta

re-calculates the net delta of all the open positions and re-balances the hedged delta
by buying/selling perps on snx.


```solidity
function reHedgeDelta() external onlyOwner;
```

### receive


```solidity
receive() external payable;
```

### withdrawTokens

withdraws ERC20/ERC721 tokens owned by the owner.


```solidity
function withdrawTokens(IERC20 token) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`||


### withdrawEth

allows owner of the account to withdraw ETH from the account


```solidity
function withdrawEth(uint256 amount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`||


## Errors
### EthWithdrawalFailed
thrown when ETH transferred from the account fails.


```solidity
error EthWithdrawalFailed();
```

### OptionTokenWithdrawalFailed
thrown when the owner tries to withdraw optionToken.


```solidity
error OptionTokenWithdrawalFailed();
```

