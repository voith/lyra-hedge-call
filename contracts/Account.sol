// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Initializable} from "openzeppelin-contracts-4.4.1/proxy/utils/Initializable.sol";
import {Ownable} from "openzeppelin-contracts-4.4.1/access/Ownable.sol";
import "./LyraSNXHedger.sol";

contract Account is Initializable, LyraSNXHedger, Ownable {
    error EthWithdrawalFailed();

    function initialize(
        address _owner,
        ILyraRegistry _lyraRegistry,
        OptionMarket _optionMarket,
        IPerpsV2MarketConsolidated _perpsMarket,
        IAddressResolver _addressResolver,
        IERC20 _quoteAsset,
        IERC20 _baseAsset,
        SynthetixPerpsAdapter.SNXPerpsV2PoolHedgerParameters memory _futuresPoolHedgerParams
    ) external initializer {
        super.initialize(
            _lyraRegistry,
            _optionMarket,
            _perpsMarket,
            _addressResolver,
            _quoteAsset,
            _baseAsset,
            _futuresPoolHedgerParams
        );
        _transferOwnership(_owner);
    }

    function buyHedgedCall(uint256 strikeId, uint256 amount) external onlyOwner {
        _buyHedgedCall(strikeId, amount);
    }

    function reHedgeDelta() external onlyOwner {
        _reHedgeDelta();
    }

    function updatePerpsCollateral() external onlyOwner {
        _updateCollateral();
    }

    receive() external payable {}

    function withdrawTokens(IERC20 token) external onlyOwner {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function withdrawEth(uint256 amount) external onlyOwner {
        if (amount > 0) {
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            if (!success) revert EthWithdrawalFailed();
        }
    }
}
