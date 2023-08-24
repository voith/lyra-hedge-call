// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IPerpsV2MarketConsolidated} from "@lyrafinance/protocol/contracts/interfaces/perpsV2/IPerpsV2MarketConsolidated.sol";
import {ICurve} from "@lyrafinance/protocol/contracts/interfaces/ICurve.sol";
import {BaseExchangeAdapter} from "@lyrafinance/protocol/contracts/BaseExchangeAdapter.sol";
import {OptionMarket} from "@lyrafinance/protocol/contracts/OptionMarket.sol";
import {IAddressResolver} from "@lyrafinance/protocol/contracts/interfaces/IAddressResolver.sol";
import {IPerpsV2MarketSettings} from "@lyrafinance/protocol/contracts/interfaces/perpsV2/IPerpsV2MarketSettings.sol";
import {IERC20} from "openzeppelin-contracts-4.4.1/token/ERC20/IERC20.sol";
import "@lyrafinance/protocol/contracts/synthetix/DecimalMath.sol";
import "@lyrafinance/protocol/contracts/synthetix/SignedDecimalMath.sol";
import "openzeppelin-contracts-4.4.1/utils/math/SafeCast.sol";
import "@lyrafinance/protocol/contracts/libraries/Math.sol";


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
    // TODO: remove this address
    address snxPoolHedger = 0x6a2E646c5caF92820C00f501E04FE1a0EC9f37bd;

    // testing address
    address user = address(0x51);
    uint256 targetBlock = 108652673;

    function setUp() external {
        string memory OPTIMISM_RPC_URL = vm.envString("OPTIMISM_RPC_URL");
        optimismFork = vm.createFork(OPTIMISM_RPC_URL);
        vm.selectFork(optimismFork);
        vm.rollFork(targetBlock - 5);
        deal(user, 100 ether);
        deal({token: address(usdc), to: user, give: 10000e6});
        exchangeUSDCforSUSD(user, 5000e6);
    }

    function exchangeUSDCforSUSD(address account, uint256 amountIn) internal returns(uint256 amountOut){
        vm.startPrank(account);
        usdc.approve(address(curveSwap), amountIn);
        amountOut = curveSwap.exchange_with_best_rate(
          address(usdc),
          address(sUSD),
          amountIn,
          0,
          user
        );
        vm.stopPrank();
    }

    function _getFuturesMarketSettings() internal view returns (IPerpsV2MarketSettings) {
        return IPerpsV2MarketSettings(addressResolver.getAddress(FUTURES_SETTINGS_CONTRACT));
    }

    function testSNX() external {
        uint256 targetLeverage = 1100000000000000000;
        uint256 maximumFundingRate = 20000000000000000;
        uint256 deltaThreshold = 60000000000000000000;
        uint256 marketDepthBuffer = 1500000000000000000;
        uint256 priceDeltaBuffer = 1050000000000000000;
        uint256 worstStableRate = 1030000000000000000;
        uint256 maxOrderCap = 10000000000000000000000;
        uint256 spotPrice = exchangeAdapter.getSpotPriceForMarket(
            address(ethOptionMarket),
            BaseExchangeAdapter.PriceType.REFERENCE
        );
        int256 size = 1e18;
        uint256 desiredCollateral = Math.abs(size).multiplyDecimal(spotPrice).divideDecimal(
            targetLeverage
        );
        uint256 minMargin = _getFuturesMarketSettings().minInitialMargin();
        if (desiredCollateral < minMargin && size != 0) {
             desiredCollateral = minMargin;
        }
        (uint feeDollars, ) = ethPerpsMarket.orderFee(size, IPerpsV2MarketConsolidated.OrderType.Offchain);
        feeDollars += _getFuturesMarketSettings().minKeeperFee();
        uint256 requiredCollateral = desiredCollateral + feeDollars;

        // open order
        vm.startPrank(user);
        sUSD.approve(address(ethPerpsMarket), type(uint256).max);
        ethPerpsMarket.transferMargin(int(requiredCollateral));
        uint desiredFillPrice = size > 0 ? spotPrice.multiplyDecimal(priceDeltaBuffer) : spotPrice.divideDecimal(priceDeltaBuffer);
        ethPerpsMarket.submitOffchainDelayedOrder(size, desiredFillPrice);
        vm.stopPrank();

        // execute order
        bytes[] memory priceUpdateData = new bytes[](1);
        priceUpdateData[0] = hex"01000000030d00b612a5da993dfa574ee31109ae4c81923b3c128f11c6bff48348c90077fc85d743900cc41a5832fe4fe16931fab6f36abc901cf2df5e27281cf8085b88e2e5530001b67cf9fbf86d561c1791c93e3d548689c2b1c22517d2a195770d1c639e42d1de10b3f20cdb1af77ccfd3b6164033b3002533753b0af8fbc17d78366f295b341800028c9c1f391a2fd50cc780321228a6fff8f4e24d64dcbcc47771e8ff73dcc413310c53a9b36e9a62e5e2c8001e04f961d92576f801edaab05b9ac29cf81554d4d00103a5f8c5e6bbb4fb23e196718f446dd8f3189037f118aca2093d12e93fb672885032d206210339390cf2dabbca31ca14cd0431aa3ba8dd7414b396d527782332cd0104b7170507d999a3c6361e089055d467ef07db874de9e9f4c41d36d872f58d0ab41b5249120952685be45bc03d3023d7e2dbfe86c34a24e3771c3d6070fb40d38f0109876f7cf6fa9e1e546d242023342578d6a94aa18dab79e35dccf73f81ef4d724275a5311240fa1fa6196d8283a91711bb435edcf7e3d4a84792e4fa3bef7a2cf9000ac5aa5f751872e5f811a6ad52aa10d65f28755de9a7251dd8146a3df8ec2816ec213465de89c2f4b63996a3582c999affb1d96fabb9bd9339c62f8124cf9b3eed000b3124c7134e11bcf97598367c8a293a77c6a98014d34acf87f81176c20228639d014402c4625feff5377d481e48a8c1fb00ee86805a34c36d31c4fbbba5e05de3000df78b2809ff2d62551d0398f28478363d83fbf0886ddc892f9e74760682f9b764085dafbe6b4b0f0c5bf6012e541faacecb2b00f25880eb06e25642998ef14e79010e448416bc2404e3675b6542a8b2aa3df70f390d0d1e6b6838d03a9c648460e2bd3aa0aa787fb7e137e92db0f2f5a8321e61b447a150f063b8276f2d19c823306d010f280f1c9f7a80c97c8e880a555475fa5ed325ee43d8ef31b39135419bf1dafb63237023359e806496f3c2865778081926fac0d86b74a0873de39f2195461ecb2a0111829678821611b6010588620bc6ab894a61c470b581c2743da58d8680cd93f7b91fad1433d52fe0350bfad4c319f3afe8095ca42fa50df0c3dcede3bb278f71960112dc981467bb5782eb4caea95077a2f69decd1e6d7d62b5cf6bec80ada5e7c453d79fd48e5de1b2c75e0fad8321657fa1b73f5f61c56d19f3c7e0c1b332c0bed9e0064e7aab700000000001af8cd23c2ab91237730770bbea08d61005cdda0984348f3f6eecb559638c0bba000000000249200670150325748000300010001020005009d04028fba493a357ecde648d51375a445ce1cb9681da1ea11e562b53522a5d3877f981f906d7cfe93f618804f1de89e0199ead306edc022d3230b3e8305f391b0000000263dbb09dc00000000071b22f2fffffff800000026460ee6f80000000008dc6b5d010000000c0000000f0000000064e7aab70000000064e7aab70000000064e7aab6000000263dbb09dc00000000071b22f20000000064e7aab6e6c020c1a15366b779a8c870e065023657c88c82b82d58a9fe856896a4034b0415ecddd26d49e1a8f1de9376ebebc03916ede873447c1255d2d5891b92ce57170000002818220cb4000000000d754767fffffff8000000281ddd4fd8000000000e85be4801000000090000000b0000000064e7aab70000000064e7aab60000000064e7aab60000002818220cb4000000000d7547670000000064e7aab5c67940be40e0cc7ffaa1acb08ee3fab30955a197da1ec297ab133d4d43d86ee6ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace000000264affe8e10000000005bfd2fffffffff8000000265141867000000000052e44e7010000001a000000200000000064e7aab70000000064e7aab70000000064e7aab6000000264b00e0990000000005bedb470000000064e7aab68d7c0971128e8a4764e757dedb32243ed799571706af3a68ab6a75479ea524ff846ae1bdb6300b817cee5fdee2a6da192775030db5615b94a465f53bd40850b50000002644bc2af4000000000ad42b7afffffff8000000264d98ae68000000000ae8575f010000000c0000000d0000000064e7aab70000000064e7aab70000000064e7aab60000002644bc2af4000000000ad42b7a0000000064e7aab6543b71a4c292744d3fcf814a2ccda6f7c00f283d457f83aa73c41e9defae034ba0255134973f4fdf2f8f7808354274a3b1ebc6ee438be898d045e8b56ba1fe1300000000000000000000000000000000fffffff8000000000000000000000000000000000000000003000000080000000064e7aab70000000064e7aab60000000000000000000000000000000000000000000000000000000000000000";
        vm.rollFork(targetBlock - 1);
        ethPerpsMarket.executeOffchainDelayedOrder{value:1}(user, priceUpdateData);

        IPerpsV2MarketConsolidated.Position memory pos = ethPerpsMarket.positions(user);
        assertEq(uint256(size), uint256(uint128(pos.size)));
    }

//    function testExecute() external {
//        vm.rollFork(108648327);
//        address target = 0x3d36ec8131F89cC454434DB3889DA8CFe37BB06c;
//        bytes[] memory priceUpdateData = new bytes[](1);
//        priceUpdateData[0] = hex"01000000030d00aeba7d8b5061fadf5da426d4cd368b7e322cd168debb44441dde6b224a61817f03cb69ab366ae851935c22228268002ce8b0a5dabf0f37f28c48d89482b21b220002065c04893d71414a94bc1c86eff24b7e256d28bdd89b4f63fd190be56ccf20e130b2694a5cbcd4549a357df587e0892fe35bf1750513c8fe5e65354e7057a378000357f08ba11303595281c8820d6fd948ed9847cc8edd5347bd55f74665bf0d9bc2036947e674fb8fa97240af42df6b400bf34be0c47950138f0e41fab6eda2564c000415b9bdfeebbfeb3f830ddf8102a24a8174836dff353eb8a70668fee4a66fe7940007aa5932554f454f8327c94f73a71b7056907971b9a046d844b16639b866580109b4490435e7147487405eedce4e6fbcfad3888cdb05803489fd78272b742e38ef7df909d4184d886e71339904691bb632f790a87131c2730ec3e3ffc2b65e07a0000abfd9f95bef7056f8257e4be4f67bcad69a718a1553437f9308df807d7a9c736769863a4a0aab4e81e00ce8582f9a18d54467fb846593b94da918623a71dcc423010b11498098671f9b4bf98d67ac2857d89d96e3b51db66e59d413c9ca23ab9861a3415cdee9d6a21d5f9ff5f1d5836a5a1cdab522c304ab074c4376968b71d3db21010c11c1c43e95ee26010526a8580d8e4c64ad3d9c03baf869330ef79e79c52776c638318ad6531c27ef990dc23de2694cd149f9f4d719c96b01bfcb303965d9a35f010edc997e766932d7a1c82675c7f98e3c96da49f41918836c2d7e0383ab36ecb79703f5fc65598da7a7a08b85a1326def0223cdec70a692ef53d7662925bca340fb000f6c5412c914c0a4023ec6d4c2ebb4b323292d6685d495c5997b61e8c21f57ac801fa32c6f31df78cfa7e38e101deb4e974e654160a8398386b416949f76ce4cfe00100c4e2600306a622a5450f07f9fe9f2200e2b4e044bb53f3308d4fcf05c47b46f7e71d189ba3918b129735f4b86c53d3a53bafe6244700e6cc49f7e91bd3387d3011199334f6abe001fbfa880b71166cb8717a3e2d64ba1b5e710af73d6d33a63ec393bf1017c5cde36c9663cc0f012720727a9a2f4e6ebb0db86bbd2654034f2fa610012f3fb4e24b910c2974a4362f7559461a91bfe4e906217d6b30def33dcddc9497470c389e06fe951df6f3737e38b5f76a300a0142ef90c0a19fe90157ae640f9780164e788c700000000001af8cd23c2ab91237730770bbea08d61005cdda0984348f3f6eecb559638c0bba000000000248ec6ed0150325748000300010001020005009d04028fba493a357ecde648d51375a445ce1cb9681da1ea11e562b53522a5d3877f981f906d7cfe93f618804f1de89e0199ead306edc022d3230b3e8305f391b0000000267984e1a60000000009832d44fffffff800000026584a0ff00000000009196f81010000000c0000000f0000000064e788c70000000064e788c70000000064e788c6000000267984e1a600000000099ea8f10000000064e788c6e6c020c1a15366b779a8c870e065023657c88c82b82d58a9fe856896a4034b0415ecddd26d49e1a8f1de9376ebebc03916ede873447c1255d2d5891b92ce5717000000284adf83700000000010db13f6fffffff8000000282bee37e0000000000e13609a01000000090000000b0000000064e788c70000000064e788c50000000064e788c4000000284e500007000000000d6a975f0000000064e788c5c67940be40e0cc7ffaa1acb08ee3fab30955a197da1ec297ab133d4d43d86ee6ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace00000026854ff14a00000000067b363efffffff80000002663b7570800000000055510c0010000001a000000200000000064e788c70000000064e788c70000000064e788c60000002684f8376f0000000005af6e510000000064e788c68d7c0971128e8a4764e757dedb32243ed799571706af3a68ab6a75479ea524ff846ae1bdb6300b817cee5fdee2a6da192775030db5615b94a465f53bd40850b500000026802cfdff00000000098ab804fffffff80000002660789340000000000b5eeefe010000000c0000000d0000000064e788c70000000064e788c70000000064e788c6000000268137ed740000000009ec55830000000064e788c6543b71a4c292744d3fcf814a2ccda6f7c00f283d457f83aa73c41e9defae034ba0255134973f4fdf2f8f7808354274a3b1ebc6ee438be898d045e8b56ba1fe1300000000000000000000000000000000fffffff8000000000000000000000000000000000000000003000000080000000064e788c70000000064e788c60000000000000000000000000000000000000000000000000000000000000000";
//        ethPerpsMarket.executeOffchainDelayedOrder{value:1}(target, priceUpdateData);
//    }
}

//for(uint i=0; i < 100; i++){
//            console.logBytes32(vm.load(snxPoolHedger, bytes32(i)));
//}