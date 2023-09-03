### Lyra Hedge Call Demo

#### Installation
```bash
$ yarn
$ curl -L https://foundry.paradigm.xyz | bash
$ foundryup
$ git submodule update --init --recursive
```

#### Testing
```bash
$ FOUNDRY_PROFILE="fork" forge test -vvv --fork-url <OPTIMISM_RPC_URL>
```
**Note**: *replace `<OPTIMISM_RPC_URL>` with an actual node url for Optimism mainnet.*

*Some notes on testing*
- Foundry evm is not fully compliant with optimism's EVM. `vm.rollFork` doesn't sync block changes after calling it more than once inside the test function.
   However, `vm.rollFork` works fine inside the `setUp` function.
   Because of this, each test had to moved to a separate Test contract. This way every test can have its own `setUp` function.
- The fork tests roll to blocks that have already been finalised. Positions that the tests open get overriden by a new owner when the test rolls to a new block.
  For this reason, the tests re-open new positions to mock options that were opened at a previous block.

#### Architecture

![architecture](./static/LyraSnxHedgeStrategy-Architecture.jpeg)

#### Design Notes

TODO

#### Example

TODO

#### Design consideration and Limitations

TODO
