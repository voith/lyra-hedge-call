// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {UpgradeableBeacon} from "openzeppelin-contracts-4.4.1/proxy/beacon/UpgradeableBeacon.sol";
import {AccountProxy} from "./AccountProxy.sol";
import "./Account.sol";

/// @title Account Factory
/// @author Voith
/// @notice Factory for creating accounts for users.
/// @dev the factory acts as a beacon for the proxy {AccountProxy.sol} contract(s)
contract AccountFactory is UpgradeableBeacon {
    /// @dev mapping of the owner address and the Account instance owned by the owner.
    mapping(address => address) private accounts;
    /// @dev address of Lyra's LyraRegistry contract
    ILyraRegistry lyraRegistry;
    /// @dev address of Lyra's OptionMarket contract
    OptionMarket optionMarket;
    /// @dev address of Synthetix's PerpsV2Market contract
    IPerpsV2MarketConsolidated perpsMarket;
    /// @dev address of Synthetix's AddressResolver contract
    IAddressResolver addressResolver;
    /// @dev address of QuoteAsset(USDC normally).
    IERC20 quoteAsset;
    /// @dev address of baseAsset(sUSD normally).
    IERC20 baseAsset;
    /// @dev parameters for opening perps on snx.
    SynthetixPerpsAdapter.SNXPerpsParameters snxPerpsParams;
    /// @dev address of Lyras OptionToken
    OptionToken optionToken;

    /// @notice thrown when a user tries to create a new Account and if an Account already exists for teh user.
    error AccountAlreadyExistsError(address account);

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
    ) UpgradeableBeacon(_implementation) {
        lyraRegistry = _lyraRegistry;
        optionMarket = _optionMarket;
        optionToken = _optionToken;
        perpsMarket = _perpsMarket;
        addressResolver = _addressResolver;
        quoteAsset = _quoteAsset;
        baseAsset = _baseAsset;
        snxPerpsParams = _snxPerpsParams;
    }

    /// @notice create unique account proxy for function caller
    /// @return accountAddress address of account created
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
                        optionToken,
                        perpsMarket,
                        addressResolver,
                        quoteAsset,
                        baseAsset,
                        snxPerpsParams
                    )
                )
            )
        );
        accounts[msg.sender] = address(accountAddress);
    }

    /// @param _owner: address of the owner
    /// @return address of the Account owned by _owner
    function getOwnerAccountAddress(address _owner) external view returns (address) {
        return accounts[_owner];
    }
}
