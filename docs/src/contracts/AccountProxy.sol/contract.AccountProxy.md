# AccountProxy
[Git Source](https://github.com/voith/lyra-hedge-call/blob/f873497d985505e623005b128f0ef7e378dfeab4/contracts/AccountProxy.sol)

**Inherits:**
BeaconProxy

**Author:**
Voith

*This contract implements a proxy that gets the
implementation address for each call from the {Beacon}
(which in this system is the contract: {AccountFactory.sol}).*


## Functions
### constructor


```solidity
constructor(address _implementation, bytes memory data) BeaconProxy(_implementation, data);
```

