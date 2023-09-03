// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Initializable} from "openzeppelin-contracts-4.4.1/proxy/utils/Initializable.sol";
import {Ownable} from "openzeppelin-contracts-4.4.1/access/Ownable.sol";
import "./LyraSNXHedgeStrategy.sol";

/// @title Account Implementation with Hedging Capabilities
/// @author Voith
/// @notice account that allows users to buy on-chain derivatives and has hedging capabilities
/// @dev credits: This contract is inspired by kwenta's smart margin account. (https://github.com/Kwenta/smart-margin/blob/main/src/Account.sol)
contract Account is Initializable, LyraSNXHedgeStrategy, Ownable {
    /// @notice thrown when ETH transferred from the account fails.
    error EthWithdrawalFailed();
    /// @notice thrown when the owner tries to withdraw optionToken.
    error OptionTokenWithdrawalFailed();

    /// @dev Initialize the contract.
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
    ) external initializer {
        super.initialize(
            _lyraRegistry,
            _optionMarket,
            _optionToken,
            _perpsMarket,
            _addressResolver,
            _quoteAsset,
            _baseAsset,
            _snxPerpsParams
        );
        _transferOwnership(_owner);
    }

    /// @notice buys a call for a given strikeId and amount and the hedges the delta of the option by selling perps on snx.
    /// @param strikeId: id of strike against which the option will be opened
    /// @param amount: amount of the options to buy
    function buyHedgedCall(uint256 strikeId, uint256 amount) external onlyOwner {
        _buyHedgedCall(strikeId, amount);
    }

    /// @notice re-calculates the net delta of all the open positions and re-balances the hedged delta
    /// by buying/selling perps on snx.
    function reHedgeDelta() external onlyOwner {
        _reHedgeDelta();
    }

    receive() external payable {}

    /// @notice withdraws ERC20/ERC721 tokens owned by the owner.
    /// @param token: address of the token
    function withdrawTokens(IERC20 token) external onlyOwner {
        if (address(token) == address(optionToken)) revert OptionTokenWithdrawalFailed();
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    /// @notice allows owner of the account to withdraw ETH from the account
    /// @param amount: amount of eth to withdraw
    function withdrawEth(uint256 amount) external onlyOwner {
        if (amount > 0) {
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            if (!success) revert EthWithdrawalFailed();
        }
    }
}
