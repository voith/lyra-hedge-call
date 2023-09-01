// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BeaconProxy} from "openzeppelin-contracts-4.4.1/proxy/beacon/BeaconProxy.sol";

contract AccountProxy is BeaconProxy {
    constructor(address _implementation, bytes memory data) BeaconProxy(_implementation, data) {}
}
