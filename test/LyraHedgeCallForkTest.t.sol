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
import "@lyrafinance/protocol/contracts/synthetix/DecimalMath.sol";
import "@lyrafinance/protocol/contracts/synthetix/SignedDecimalMath.sol";
import "openzeppelin-contracts-4.4.1/utils/math/SafeCast.sol";
import "@lyrafinance/protocol/contracts/libraries/Math.sol";
import {IERC20} from "openzeppelin-contracts-4.4.1/token/ERC20/IERC20.sol";

import {LyraSNXHedger} from "contracts/LyraSNXHedger.sol";
import {SynthetixPerpsAdapter} from "contracts/SynthetixPerpsAdapter.sol";

contract LyraHedgeCallForkTest is Test {
    using DecimalMath for uint256;
    using SignedDecimalMath for int256;

    uint256 optimismFork;
    IERC20 usdc = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    IERC20 sUSD = IERC20(0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9);
    bytes32 constant FUTURES_SETTINGS_CONTRACT = bytes32("PerpsV2MarketSettings");
    bytes32 marketKey = bytes32("sETHPERP");
    IPerpsV2MarketConsolidated ethPerpsMarket = IPerpsV2MarketConsolidated(0x2B3bb4c683BFc5239B029131EEf3B1d214478d93);
    ICurve curveSwap = ICurve(0x05d4E2Ed7216A204e5FB4e3F5187eCfaa5eF3Ef7);
    OptionMarket ethOptionMarket = OptionMarket(0x59c671B1a1F261FB2192974B43ce1608aeFd328E);
    BaseExchangeAdapter exchangeAdapter = BaseExchangeAdapter(0x2b1dF9A55Ceb1bba7D830C1a6731ff37383c4A53);
    IAddressResolver addressResolver = IAddressResolver(0x95A6a3f44a70172E7d50a9e28c85Dfd712756B8C);
    ILyraRegistry lyraRegistry = ILyraRegistry(0x0FEd189bCD4A680e05B153dC7c3dC87004e162fb);
    OptionToken ethOptionToken = OptionToken(0xA48C5363698Cef655D374675fAf810137a1b2EC0);
    // TODO: remove this address
    address snxPoolHedger = 0x6a2E646c5caF92820C00f501E04FE1a0EC9f37bd;

    LyraSNXHedger lyraHedger;

    // testing address
    address user = address(0x51);
    uint256 targetBlock = 107965799;

    function setUp() external {
        string memory OPTIMISM_RPC_URL = vm.envString("OPTIMISM_RPC_URL");
        optimismFork = vm.createFork(OPTIMISM_RPC_URL);
        vm.selectFork(optimismFork);
        vm.rollFork(targetBlock - 5);
        lyraHedger = new LyraSNXHedger(
            lyraRegistry,
            ethOptionMarket,
            ethPerpsMarket,
            addressResolver,
            usdc,
            sUSD,
            SynthetixPerpsAdapter.SNXPerpsV2PoolHedgerParameters({
                targetLeverage: 1100000000000000000,
                priceDeltaBuffer: 1050000000000000000
            })
        );
        fundAccount(user);
    }

    function fundAccount(address account) internal {
        deal(account, 100 ether);
        deal({token: address(usdc), to: account, give: 100000e6});
        exchangeUSDCforSUSD(account, 10000e6);
    }

    function exchangeUSDCforSUSD(address account, uint256 amountIn) internal returns (uint256 amountOut) {
        vm.startPrank(account);
        usdc.approve(address(curveSwap), amountIn);
        amountOut = curveSwap.exchange_with_best_rate(address(usdc), address(sUSD), amountIn, 0, user);
        vm.stopPrank();
    }

    function executeOffchainDelayedOrder(uint256 _targetBlock, bytes memory _priceUpdateData) internal {
        bytes[] memory priceUpdateData = new bytes[](1);
        priceUpdateData[0] = _priceUpdateData;
        vm.rollFork(_targetBlock);
        ethPerpsMarket.executeOffchainDelayedOrder{value: 1}(address(lyraHedger), priceUpdateData);
    }

    function testBuyHedgedCall() external {
        uint256 strikeID = 262;
        uint256 optionsAmount = 2;

        vm.startPrank(user);
        usdc.transfer(address(lyraHedger), 5000e6);
        sUSD.transfer(address(lyraHedger), 5000e18);
        vm.stopPrank();

        lyraHedger.buyHedgedCall(strikeID, optionsAmount);
        OptionToken.OptionPosition[] memory optionTokens = ethOptionToken.getOwnerPositions(address(lyraHedger));
        assertEq(optionTokens.length, 1);
        assertEq(optionTokens[0].strikeId, strikeID);
        assertEq(uint(optionTokens[0].optionType), uint(OptionMarket.OptionType.LONG_CALL));

        int256 delta = lyraHedger.getDelta(strikeID);
        int256 hedgedDelta = int(optionsAmount) * delta * int(-1);

        // execute order
        bytes memory priceUpdateData = hex"01000000030d0008e7881301d2b9548ade09f491ca533472e4ce514751126c1e6f385932527e271170a14fa80d7e08281dcb8eae2c17ffe80d5383d4eb59aa97b3466071fc5e5101013ed14784a0dc47881865d279aaf9f5155a930963d0f2be2a416c31c1c53e78322fb67b66b0ae2fb378f283a98450bd47fe2c81cdf641fa4dbf15b812959cf7ba01022b0f28168f4503db8456cf398d21d04d462eeeb4b4bf4a3d1117034bf3231c02599c29d297905ddcdbde3405bcc66e93d381b223caa1ca4df3ca15429d59c7e80003efecb1333e4ea5e12fd2a0f8267ce555ceca4fd85e5217b205f161e93b0b3d45140816d03abe82894ea7ca4012407368362d2932ac91705a315ba467c2d38f860004fe33eded697962a6884f7d41d9555915a95b1cedbb1f497fd2ee7fcb76b0209c48f4cd6e2740a09536401d4ed5bbb3bc2be2dbd9c4c9a23ef35cb328eae4c96e010a984146fa535b225181782aa8bf765f1ae2b145e62d91e59be1e1ad097d0716a127ad90bc6cc1fff2dbb037a531b2190cc8acad160503b7fe7b00535e626766f2000bae896af911915e93ae12f72470289c09c81a0c8af7ddd89d83b3857191325ab516e7b371ee18288fc9620eea760a089e56cd24ac42d0a9364e7b80a8038c063a000c62dbfe7a36067cf576e52960da5ca025415512421d4747c412941fb89dc0b13a155fb6aacdbd4761a8bd042694c5e774b190220df080c8ce789c7be0128bc8dc010d96bd0c6be7ce8b5a901bd3b32ccfb82269a5edd357caec13e3ea85b86773b0de5ff010037208dfe55a0156cdfcff22da76507965d79ebc8221a9619ca1812101010facbfd0fe74cc9f11dd0ffff2804be57fcd6750bedc488c29b2c53da951476eb93b447afd0326bdc4838d2c80fe3db92a5333b2d7e9454479b99bcee63493474801103b675569d49f67dcc87ff1f025eca687c7e9ef20d8b679618bbf4cafd025911634d2a360a892792907641c55c48b8e2221f1609800ed58de5d681d579289498f01111e45245efd57a0ea7da7b1d3dbc3b225d1af72936ddb319391cd33c27d33938358adefc9c2f31babe3b72a75ca37e460f0f511acdfd213bbc2ca47fa77ea87ee011217a88be856f798ea888307945acb0fe84d47f9eef648d0a2b86ebdb8010a1e2c328125b1a83c9d9508f2ef772382dddec2445df610db9b251e809ea5c64338010064d2b48400000000001af8cd23c2ab91237730770bbea08d61005cdda0984348f3f6eecb559638c0bba000000000229d6c810150325748000300010001020005009d04028fba493a357ecde648d51375a445ce1cb9681da1ea11e562b53522a5d3877f981f906d7cfe93f618804f1de89e0199ead306edc022d3230b3e8305f391b00000002b57d02f6d000000000a7c9b5ffffffff80000002b550746f00000000008f8d588010000000c0000000f0000000064d2b4840000000064d2b4840000000064d2b4820000002b57d02f6d000000000a7c9b5f0000000064d2b482e6c020c1a15366b779a8c870e065023657c88c82b82d58a9fe856896a4034b0415ecddd26d49e1a8f1de9376ebebc03916ede873447c1255d2d5891b92ce57170000002d3b06f6f4000000001d72baf1fffffff80000002d348e7a6800000000193fca0a01000000070000000a0000000064d2b4840000000064d2b4840000000064d2b4820000002d3b06f6f40000000016e5cf0c0000000064d2b481c67940be40e0cc7ffaa1acb08ee3fab30955a197da1ec297ab133d4d43d86ee6ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace0000002b60465c4f00000000065d8da8fffffff80000002b608819f00000000004c36d6d010000001e000000200000000064d2b4840000000064d2b4840000000064d2b4820000002b6061cc9e000000000678fdf70000000064d2b4828d7c0971128e8a4764e757dedb32243ed799571706af3a68ab6a75479ea524ff846ae1bdb6300b817cee5fdee2a6da192775030db5615b94a465f53bd40850b50000002b587bfb82000000000ad75bfdfffffff80000002b5b6fbbf8000000000bb00f71010000000b0000000c0000000064d2b4840000000064d2b4840000000064d2b4820000002b598b2a170000000009c8b9ae0000000064d2b481543b71a4c292744d3fcf814a2ccda6f7c00f283d457f83aa73c41e9defae034ba0255134973f4fdf2f8f7808354274a3b1ebc6ee438be898d045e8b56ba1fe1300000000000000000000000000000000fffffff8000000000000000000000000000000000000000001000000080000000064d2b4840000000064d2b4840000000000000000000000000000000000000000000000000000000000000000";
        // fast forward chain and execute
        executeOffchainDelayedOrder(targetBlock, priceUpdateData);
        assertEq(hedgedDelta, lyraHedger.getCurrentPerpsAmount());

        vm.rollFork(108296416);
        console.log(uint(lyraHedger.getDelta(strikeID)));

//        priceUpdateData = hex"01000000030d00e2a6214ffe3eb8b19894f09190f0a844907b57db3b4c9948b8984cb107129072646428d520c8b830421a772a667175a07b9fbc5800a3bf66bedf73fbe9b16b930102618e7e131deaf9b803539de79efab1df1cb0ce2e746b618170b27fef2083f80f3ad9455f72d5bdceeaed313cfbe3e46860c370d0870768a3e9febe467a42e2c0000370290dbe9f07a812141f018107590fb4c3dc81b0e870556049b27568b400876d7aaf16eaf45275f82d5a08d6aced49dfaf5692b6e102899a367fab54b9f9f6ec01068b12543fed625237041e9f95029e249543122ffd4c5a75c08a14370f2ef420fc6d2dd26846584daced6c57fadab464fe1a7bae55a09ed53050c525e99e3dfc7c00097d4a54b5d092a3087ac7b3bc2c4d5e5b91ebb2eec40306a3c0627eaf6a6289183d56b81dba7b37fa4af59181a2411de7e90c86f3209bcd30b709ce81fc193864010ab5b368b4e7bddd641509f6a0ced95eb5237df4804e1eccf51c02c1023896f7d46ca6ff235b47c52747ab1a0ff08599e46d36e29f6e5fc8318a2ea4848ed32885010b89cb0f6ad252f408eb8034aded78476dc476a81c20a093bccd43f87e3cdb671f19bff48fe10626fc645a91f4f025dadc65b09d43968781c54e063436102b3fb5000c0f17f9316937ec1a52284efe2385ccf55a8c43ee752de13307397bdc9553f44958ef38d44ea51ac2398168f2083e3abaf644cd2f94009d9d8a00bb75677198f1010d357fda1999bed9f6354a4a4667cc0b119d777150d4bbc15a74e87cbf01b02bb823297df724aa618deb63f2ab1bbf7fedcd83eb2048a0a3c77476e4e5cde85eb0010e66d8e4972530f20a1804772d1b4c9a98ae443ae47beb1ef8dfad3b610c21485e62ffe9aa3f2592b2fa22ca0c7e45bf6f8ab2d674f65f1dee51be145920997bb2000fe07934352dc5b85f15d066eb17b212fa661b22608388d511f03f74420cb9dcb460a211fa5538e1387033837c6803bbbce2917247c981dc96c6f57cc25a7e8e86011070b2c4b474e1ab576eabfae005cadc076b7db9a171f80565982b949f6d88e99a25c00f490a04ff82177a16459db725a2c1b1102b6f337146ef78710e01f7e7350012794607e1dccf9e7bfbd3e4baf97076b2c08f355a43de2c5f4a89401f3f59f2f02bf79342d89cd334e082a287246676ffa02d481a4999a6ecb03cfcd3c564afe90064dccb7500000000001af8cd23c2ab91237730770bbea08d61005cdda0984348f3f6eecb559638c0bba000000000238b73c60150325748000300010001020005009d04028fba493a357ecde648d51375a445ce1cb9681da1ea11e562b53522a5d3877f981f906d7cfe93f618804f1de89e0199ead306edc022d3230b3e8305f391b00000002a5f8e6911000000000f393ebffffffff80000002a64e29b98000000000fa7c811010000000d0000000f0000000064dccb750000000064dccb750000000064dccb740000002a5f8e6911000000000f393ebf0000000064dccb74e6c020c1a15366b779a8c870e065023657c88c82b82d58a9fe856896a4034b0415ecddd26d49e1a8f1de9376ebebc03916ede873447c1255d2d5891b92ce57170000002c5d2a259a000000000fac207dfffffff80000002c5e717980000000000fd69a33010000000a0000000b0000000064dccb750000000064dccb740000000064dccb740000002c5d2a259a000000000fac207d0000000064dccb74c67940be40e0cc7ffaa1acb08ee3fab30955a197da1ec297ab133d4d43d86ee6ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace0000002a6d052786000000000b50695afffffff80000002a70be4c50000000000a066c5c010000001f000000200000000064dccb750000000064dccb750000000064dccb740000002a6d052786000000000acfa1220000000064dccb748d7c0971128e8a4764e757dedb32243ed799571706af3a68ab6a75479ea524ff846ae1bdb6300b817cee5fdee2a6da192775030db5615b94a465f53bd40850b50000002a6f7fa7eb000000000b3bfb3dfffffff80000002a71fdb5d8000000000d7f653a010000000d0000000d0000000064dccb750000000064dccb750000000064dccb740000002a6f7fa7eb000000000b3bfb3d0000000064dccb74543b71a4c292744d3fcf814a2ccda6f7c00f283d457f83aa73c41e9defae034ba0255134973f4fdf2f8f7808354274a3b1ebc6ee438be898d045e8b56ba1fe1300000000000000000000000000000000fffffff8000000000000000000000000000000000000000002000000080000000064dccb750000000064dccb740000000000000000000000000000000000000000000000000000000000000000";
//        executeOffchainDelayedOrder(108296416, priceUpdateData);
    }

//    function testReHedge() external {
//
//    }
}
