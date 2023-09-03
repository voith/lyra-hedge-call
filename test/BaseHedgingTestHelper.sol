// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IPerpsV2MarketConsolidated} from "@lyrafinance/protocol/contracts/interfaces/perpsV2/IPerpsV2MarketConsolidated.sol";
import {ICurve} from "@lyrafinance/protocol/contracts/interfaces/ICurve.sol";
import {BaseExchangeAdapter} from "@lyrafinance/protocol/contracts/BaseExchangeAdapter.sol";
import {OptionMarket} from "@lyrafinance/protocol/contracts/OptionMarket.sol";
import {OptionToken} from "@lyrafinance/protocol/contracts/OptionToken.sol";
import {IAddressResolver} from "@lyrafinance/protocol/contracts/interfaces/IAddressResolver.sol";
import {IPerpsV2MarketSettings} from "@lyrafinance/protocol/contracts/interfaces/perpsV2/IPerpsV2MarketSettings.sol";
import {ILyraRegistry} from "@lyrafinance/protocol/contracts/interfaces/ILyraRegistry.sol";
import {IERC20} from "openzeppelin-contracts-4.4.1/token/ERC20/IERC20.sol";

import {Account as Account_} from "contracts/Account.sol";
import {AccountFactory} from "contracts/AccountFactory.sol";
import {SynthetixPerpsAdapter} from "contracts/SynthetixPerpsAdapter.sol";

contract BaseHedgingTestHelper is Test {
    uint256 optimismFork;
    uint256 targetLeverage = 1100000000000000000;
    IERC20 usdc = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20 sUSD = IERC20(0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9);
    bytes32 constant FUTURES_SETTINGS_CONTRACT = bytes32("PerpsV2MarketSettings");
    IPerpsV2MarketConsolidated ethPerpsMarket = IPerpsV2MarketConsolidated(0x2B3bb4c683BFc5239B029131EEf3B1d214478d93);
    ICurve curveSwap = ICurve(0x05d4E2Ed7216A204e5FB4e3F5187eCfaa5eF3Ef7);
    OptionMarket ethOptionMarket = OptionMarket(0x59c671B1a1F261FB2192974B43ce1608aeFd328E);
    BaseExchangeAdapter exchangeAdapter = BaseExchangeAdapter(0x2b1dF9A55Ceb1bba7D830C1a6731ff37383c4A53);
    IAddressResolver addressResolver = IAddressResolver(0x95A6a3f44a70172E7d50a9e28c85Dfd712756B8C);
    ILyraRegistry lyraRegistry = ILyraRegistry(0x0FEd189bCD4A680e05B153dC7c3dC87004e162fb);
    OptionToken ethOptionToken = OptionToken(0xA48C5363698Cef655D374675fAf810137a1b2EC0);

    Account_ accountImplementation;
    AccountFactory accountFactory;
    Account_ userAccount;

    // testing address
    address deployer = address(0x51);
    address user = address(0x52);
    uint256 startBlock;

    int256 oldDelta;

    function fundAccount(address _account) internal {
        deal(_account, 100 ether);
        deal({token: address(usdc), to: _account, give: 1000000e6});
        exchangeUSDCforSUSD(_account, 500000e6);
    }

    function exchangeUSDCforSUSD(address _account, uint256 amountIn) internal returns (uint256 amountOut) {
        vm.startPrank(_account);
        usdc.approve(address(curveSwap), amountIn);
        amountOut = curveSwap.exchange_with_best_rate(address(usdc), address(sUSD), amountIn, 0, user);
        vm.stopPrank();
    }

    function executeOffchainDelayedOrder(
        uint256 _targetBlock,
        bytes memory _priceUpdateData,
        address _account
    ) internal {
        bytes[] memory priceUpdateData = new bytes[](1);
        priceUpdateData[0] = _priceUpdateData;
        vm.rollFork(_targetBlock);
        ethPerpsMarket.executeOffchainDelayedOrder{value: 1}(_account, priceUpdateData);
    }

    function buyCallOption(uint256 _strikeID, uint256 _amount) internal {
        vm.startPrank(address(userAccount));
        usdc.approve(address(ethOptionMarket), type(uint).max);
        OptionMarket.TradeInputParameters memory params = OptionMarket.TradeInputParameters({
            strikeId: _strikeID,
            positionId: 0,
            optionType: OptionMarket.OptionType.LONG_CALL,
            amount: _amount,
            setCollateralTo: 0,
            iterations: 1,
            minTotalCost: 0,
            maxTotalCost: type(uint256).max,
            referrer: address(0)
        });
        ethOptionMarket.openPosition(params);
        vm.stopPrank();
    }
}
