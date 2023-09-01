// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BeaconProxy} from "openzeppelin-contracts-4.4.1/proxy/beacon/BeaconProxy.sol";

/// @title Account Proxy
/// @author Voith
/// @dev This contract implements a proxy that gets the
/// implementation address for each call from the {Beacon}
/// (which in this system is the contract: {AccountFactory.sol}).
contract AccountProxy is BeaconProxy {
    constructor(address _implementation, bytes memory data) BeaconProxy(_implementation, data) {}
}
