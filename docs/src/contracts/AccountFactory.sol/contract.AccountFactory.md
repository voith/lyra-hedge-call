# AccountFactory
[Git Source](https://github.com/voith/lyra-hedge-call/blob/cca9b2818d585390a65c6eb856ad369c2b512f4f/contracts/AccountFactory.sol)

**Inherits:**
UpgradeableBeacon

**Author:**
Voith

Factory for creating accounts for users.

*the factory acts as a beacon for the proxy {AccountProxy.sol} contract(s)*


## State Variables
### accounts
*mapping of the owner address and the Account instance owned by the owner.*


```solidity
mapping(address => address) private accounts;
```


### lyraRegistry
*address of Lyra's LyraRegistry contract*


```solidity
ILyraRegistry lyraRegistry;
```


### optionMarket
*address of Lyra's OptionMarket contract*


```solidity
OptionMarket optionMarket;
```


### perpsMarket
*address of Synthetix's PerpsV2Market contract*


```solidity
IPerpsV2MarketConsolidated perpsMarket;
```


### addressResolver
*address of Synthetix's AddressResolver contract*


```solidity
IAddressResolver addressResolver;
```


### quoteAsset
*address of QuoteAsset(USDC normally).*


```solidity
IERC20 quoteAsset;
```


### baseAsset
*address of baseAsset(sUSD normally).*


```solidity
IERC20 baseAsset;
```


### snxPerpsParams
*parameters for opening perps on snx.*


```solidity
SynthetixPerpsAdapter.SNXPerpsParameters snxPerpsParams;
```


### optionToken
*address of Lyras OptionToken*


```solidity
OptionToken optionToken;
```


## Functions
### constructor


```solidity
constructor(
    address _implementation,
    ILyraRegistry _lyraRegistry,
    OptionMarket _optionMarket,
    OptionToken _optionToken,
    IPerpsV2MarketConsolidated _perpsMarket,
    IAddressResolver _addressResolver,
    IERC20 _quoteAsset,
    IERC20 _baseAsset,
    SynthetixPerpsAdapter.SNXPerpsParameters memory _snxPerpsParams
) UpgradeableBeacon(_implementation);
```

### newAccount

create unique account proxy for function caller


```solidity
function newAccount() external returns (address payable accountAddress);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`accountAddress`|`address payable`|address of account created|


### getOwnerAccountAddress


```solidity
function getOwnerAccountAddress(address _owner) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address of the Account owned by _owner|


## Errors
### AccountAlreadyExistsError
thrown when a user tries to create a new Account and if an Account already exists for teh user.


```solidity
error AccountAlreadyExistsError(address account);
```

