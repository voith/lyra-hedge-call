# AccountProxy
[Git Source](https://github.com/voith/lyra-hedge-call/blob/6d8d03993f954009976ed0c983a934150d408004/contracts/AccountProxy.sol)

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

