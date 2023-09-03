# AccountProxy
[Git Source](https://github.com/voith/lyra-hedge-call/blob/cca9b2818d585390a65c6eb856ad369c2b512f4f/contracts/AccountProxy.sol)

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

