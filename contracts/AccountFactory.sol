// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {UpgradeableBeacon} from "openzeppelin-contracts-4.4.1/proxy/beacon/UpgradeableBeacon.sol";
import {AccountProxy} from "./AccountProxy.sol";
import "./Account.sol";

contract AccountFactory is UpgradeableBeacon {
    mapping(address => address) private accounts;

    ILyraRegistry lyraRegistry;
    OptionMarket optionMarket;
    IPerpsV2MarketConsolidated perpsMarket;
    IAddressResolver addressResolver;
    IERC20 quoteAsset;
    IERC20 baseAsset;
    SynthetixPerpsAdapter.SNXPerpsV2PoolHedgerParameters futuresPoolHedgerParams;

    error AccountAlreadyExistsError(address account);

    constructor(
        address _implementation,
        ILyraRegistry _lyraRegistry,
        OptionMarket _optionMarket,
        IPerpsV2MarketConsolidated _perpsMarket,
        IAddressResolver _addressResolver,
        IERC20 _quoteAsset,
        IERC20 _baseAsset,
        SynthetixPerpsAdapter.SNXPerpsV2PoolHedgerParameters memory _futuresPoolHedgerParams
    ) UpgradeableBeacon(_implementation) {
        lyraRegistry = _lyraRegistry;
        optionMarket = _optionMarket;
        perpsMarket = _perpsMarket;
        addressResolver = _addressResolver;
        quoteAsset = _quoteAsset;
        baseAsset = _baseAsset;
        futuresPoolHedgerParams = _futuresPoolHedgerParams;
    }

    function newAccount() external returns (address payable accountAddress) {
        if (accounts[msg.sender] != address(0)) revert AccountAlreadyExistsError(msg.sender);

        accountAddress = payable(
            address(
                new AccountProxy(
                    address(this),
                    abi.encodeWithSelector(
                        Account.initialize.selector,
                        msg.sender,
                        lyraRegistry,
                        optionMarket,
                        perpsMarket,
                        addressResolver,
                        quoteAsset,
                        baseAsset,
                        futuresPoolHedgerParams
                    )
                )
            )
        );
        accounts[msg.sender] = address(accountAddress);
    }

    function getAccountAddress(address _account) external view returns (address) {
        return accounts[_account];
    }
}
