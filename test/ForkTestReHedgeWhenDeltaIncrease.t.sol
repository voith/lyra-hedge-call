// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Math} from "@lyrafinance/protocol/contracts/libraries/Math.sol";
import "./BaseHedgingTestHelper.sol";

contract ForkTestReHedgeWhenDeltaIncrease is BaseHedgingTestHelper {
    uint256 strikeID = 66;
    uint256 optionsAmount = 2e18;

    function setUp() external {
        startBlock = 105591748; // Jun-14-2023 10:37:53 PM +UTC
        vm.rollFork(startBlock - 5);
        vm.startPrank(deployer);
        accountImplementation = new Account_();
        accountFactory = new AccountFactory(
            address(accountImplementation),
            lyraRegistry,
            ethOptionMarket,
            ethOptionToken,
            ethPerpsMarket,
            addressResolver,
            usdc,
            sUSD,
            SynthetixPerpsAdapter.SNXPerpsParameters({
                targetLeverage: 1100000000000000000,
                priceDeltaBuffer: 1050000000000000000
            })
        );
        vm.stopPrank();

        vm.prank(user);
        userAccount = Account_(accountFactory.newAccount());
        fundAccount(user);
        vm.makePersistent(address(accountImplementation), address(accountFactory), address(userAccount));
        vm.makePersistent(user);

        setupBuyHedgeCall();
    }

    function setupBuyHedgeCall() internal {
        vm.startPrank(user);
        usdc.transfer(address(userAccount), 5000e6);
        sUSD.transfer(address(userAccount), 5000e18);
        userAccount.buyHedgedCall(strikeID, optionsAmount);
        vm.stopPrank();

        OptionToken.OptionPosition[] memory optionTokens = ethOptionToken.getOwnerPositions(address(userAccount));
        assertEq(optionTokens.length, 1);
        assertEq(optionTokens[0].strikeId, strikeID);
        assertEq(uint(optionTokens[0].optionType), uint(OptionMarket.OptionType.LONG_CALL));

        int256 delta = userAccount.getDelta(strikeID);
        int256 hedgedDelta = (int(optionsAmount) * delta * int(-1)) / 1e18;
        oldDelta = delta;

        bytes
            memory priceUpdateData = hex"01000000030d00e04175de35b8409af1352bc720579233ea9bf521c469c311b18ed00f4fd87bfd345244a8f838221cef13e9d05485e0e2e92e9d26564216ccf72d3b3577d5ab8600032dc2a3a649cc8f5111b636bcdb5bbe3f0dde06cd115d18cb10628639c909043a09c92292872c2aacbb060d7c5bc39aeff410f10b318c74bf573bd3ad136609f10004ad52852313323715199cd599aad713bbd2614fa5498d42287f97b8e2a48b884f63d64ac5489f02904c0d8da6d124d1308eddd6850dea00b9987b5db64b159ee200065955b606c4805b060a659c0ffd9d3d26e958ea948be3dcad7873456828bb05e66700c7f39d5dda8d917e875831e2ad3d7ff170aad60f91f9dd958856709a619001084a8d4ed88fd6d9f8ebd2c977444ceb54ca5996d39f05509117c080379e380c695fa362c3dbb7e34feac689ddd9546832980f583675185290cbfab8453a52b131000ba925ec20c3902b46293c0e7847dc79386c494118e01ec0b8dbf9eb5d413e1242769349a7eb82417cadb6cfcbb472d57046873eedc5554943c70d07a770438556010c754a532900ab306cfd02f7d0262fd7eaf9064ba9aad3fb4b5109a0b4908fd88d584f0b8aeae0eb7dc365aec063c03e7f3160ff9f920da7fb6fbf94c6358886aa000d900d3f819867206e711f79d280d5e0a10241ac6ead6415634685dc52695c7a0c0c25a801c593f19ddccd3e235a069bebf5ffdf2d245a8fda913b3f2d03186f61000ecfe4e8d4cb45575e9255782484de909793300d33ab7a78f709262e4de73c152f6f901b403bf265ce0bde69d995ece02adb845b5997155f43957b261c56ab3df7000f4482901206ff0546f706b42a0511bfe82c8735ca6e12cd3e6ff2ba8b44ac5e2628cb4e5d1685b26f1cec3c0e2ff5c5f28e1594ed501dc678d5cb91058fdbd96b0110d6620493421b5656e1533106fd54bfc8262e0169e47612223015af23b6f3fa9b4ff69e2ea9dafee6e3374d8de579195b62893b2b8558538c550509baf83c0e990011d1f11b53e0f92b6221f7dcbdbcbb72b50eeb9e055f81b8e768574d1474faf970457a3e85d2cf43cc90f49a90b8e436262f5acadbeaa1d835feb92db376c72f6d001277ffd5846f1d1e034437c6acde6b2c7bc56e4e49b6adb9aa62dffb5557ab87ae3407b9a5ff926db2f6763fd11b32893d4acf3c07eb6e66f3ff7a958cf163283800648a413c00000000001af8cd23c2ab91237730770bbea08d61005cdda0984348f3f6eecb559638c0bba0000000001c441ae80150325748000300010001020005009d04028fba493a357ecde648d51375a445ce1cb9681da1ea11e562b53522a5d3877f981f906d7cfe93f618804f1de89e0199ead306edc022d3230b3e8305f391b00000002664f2e6330000000007711748fffffff8000000268d0963800000000007eec048010000000c0000000e00000000648a413c00000000648a413c00000000648a413b0000002664f2e633000000000771174800000000648a413ae6c020c1a15366b779a8c870e065023657c88c82b82d58a9fe856896a4034b0415ecddd26d49e1a8f1de9376ebebc03916ede873447c1255d2d5891b92ce571700000027e26cb69f0000000007b8035ffffffff8000000280d4ec1880000000009691dbd01000000070000000800000000648a413c00000000648a413c00000000648a413b00000027e26cb69f0000000007b8035f00000000648a413ac67940be40e0cc7ffaa1acb08ee3fab30955a197da1ec297ab133d4d43d86ee6ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace0000002671aa02a5000000000469719cfffffff8000000269c6f1d8800000000054533c8010000001a0000002000000000648a413c00000000648a413c00000000648a413b0000002671bd1575000000000475ed8b00000000648a413a8d7c0971128e8a4764e757dedb32243ed799571706af3a68ab6a75479ea524ff846ae1bdb6300b817cee5fdee2a6da192775030db5615b94a465f53bd40850b50000002666e0a18c00000000081e4f7bfffffff80000002690966a70000000000c28726801000000080000000900000000648a413c00000000648a413c00000000648a413b0000002666e0a18c00000000081e4f7b00000000648a413a543b71a4c292744d3fcf814a2ccda6f7c00f283d457f83aa73c41e9defae034ba0255134973f4fdf2f8f7808354274a3b1ebc6ee438be898d045e8b56ba1fe1300000000000000000000000000000000fffffff80000000000000000000000000000000000000000000000000800000000648a413c00000000648a413b0000000000000000000000000000000000000000000000000000000000000000";
        // fast forward chain and execute
        executeOffchainDelayedOrder(startBlock, priceUpdateData, address(userAccount));
        assertEq(hedgedDelta, userAccount.getCurrentPerpsAmount());
        // check that the leverage for perps on snx is in the ballpark range.
        // It might not be exact because of the time difference between submitting and executing order
        uint256 currentLeverage = uint256(userAccount.currentLeverage() * int(-1));
        assertApproxEqAbs(targetLeverage / 10 ** 16, currentLeverage / 10 ** 16, 2);
    }

    function testReHedgewhenDeltaIncrease() external {
        // foundry has some weird bugs for the optimism fork.
        // if the sUSD balance is not checked here than forge resets it to 0.
        assertTrue(sUSD.balanceOf(address(userAccount)) > 0);
        assertTrue(usdc.balanceOf(address(userAccount)) > 0);

        int oldHedgedDelta = userAccount.getCurrentPerpsAmount();
        uint256 newBlock = 106028900; // Jun-25-2023 01:29:37 AM +UTC

        vm.rollFork(newBlock - 10);
        // After rolling the chain, the position opened by userAccount gets overwritten.
        // This is because the positionID opened by the test was actually opened and owned by another address onchain
        // Fake this by buying an option with same strikeID and Size to test reHedging logic.
        buyCallOption(strikeID, optionsAmount);

        vm.startPrank(user);
        userAccount.reHedgeDelta();

        int256 newDelta = userAccount.getDelta(strikeID);
        assertTrue(uint256(oldDelta) < uint256(newDelta));

        int256 newHedgedDelta = (int(optionsAmount) * newDelta * int(-1)) / 1e18;
        bytes
            memory priceUpdateData = hex"01000000030d001cdf5d537ea78bb524d98f97f4db54905aa24e97fdc76b4663195eb388d83adf12894873979ca1dd9b7d36079a1c37b824aadeacfdb315e6e75f4d918b0ed81b0002a3f2bf1c2336b6fc638fdee5694d11f492b9d944f098f0c372afc31c7c3fdaf91cf252d563e2e16b4d40debf5ec6e9ae3433b57c7db8ddb19bcdd7009a1c4dd9010418be33fda386ec39f154c43f28b454c412b697a0c17d367385007e51f6aef5e15be58399ab0a92a3fa49ddda4f69d12fba7f5cb4f364a35e04fc0cdd6f05c55d00069737444bc7932e622bb5832240c489ab41dd51bcff664c83f2be6eac16c8b4bb23f25c0d66d481ea3eeec02692c509f1a1d7dd0cdd38e6e1647ab636590330a90008da860fa54860e5ac91ef5de1d39fb1d8cc2f19afe403f63f1381ae95dd2dd9124c0acb4d527a84fccc0ac84dcada2c7f2650e028c8c1ebbb4ab4d2aee500c9f4010a4ebd28872a5763d921e7a220c9297dea13b2def69041950f11df5ae0d417e6e35d67ee8a6154b24c50fbe0f5f41b99ad854d043cadeebaf4cc7ee5fe87111d5f010b58f7884117e801ec517f573c01d57d1edb666a86a1161dcff9295b601c400a96443b7bb1b21137382580b9752b3f8ece5ebe55cce0113ff27a7902c33ee75cd3000c39f9d64e3bc373dab5c0ee19731104638af217ca6d5a91cf743668e878b8e8b169ac58a1fca211499c526ec1295dc13c671548a5908907db4207ddb0d2594678010ddd2c3e102a9f05a691116ef3fd5c921d4c26e1a0e851a34072c4f87e925e9a0b2d290037a1818a3894ebcc3d0c16565537ba02021eb59aec2b0d194d20385fae010f179f36bfdbef04d6d1ad13770e48635b1efc6ef9a00a0bcd88d615510eefc2401176b509425082758734b105c152b71b88ddd8e321530db7e6d0a1defd8ac8f0011004d58ce8dfb1273a157a26707c2c100ec4d0824ed9bc38b3ce6fb1536ed1988e1524839bd39c24c59b2398c946318f60fff956f9b692bf9f269bec1cdd311c4f00119a82f4683103080b9a7040f33c17dedae453a5fb1ced27ef218a995aadb1f2fe7783f02dac7686dc56f8d1f940468012a61fde972cd2c249c2b87fd974e0ca030112055f88e216542dd4b63c71659eea1695d1c41aecd7dc4a69c8351df977ead9af62e62af978214556f91d07bcf0edd320ca7970b54fda6269312028a9fe4c2e4b016497987c00000000001af8cd23c2ab91237730770bbea08d61005cdda0984348f3f6eecb559638c0bba0000000001d63f3da0150325748000300010001020005009d04028fba493a357ecde648d51375a445ce1cb9681da1ea11e562b53522a5d3877f981f906d7cfe93f618804f1de89e0199ead306edc022d3230b3e8305f391b00000002bb77e1e01000000000b18eb77fffffff80000002b9de957c80000000009f060cf010000000c0000000e000000006497987c000000006497987c000000006497987b0000002bb77e1e01000000000b18eb77000000006497987be6c020c1a15366b779a8c870e065023657c88c82b82d58a9fe856896a4034b0415ecddd26d49e1a8f1de9376ebebc03916ede873447c1255d2d5891b92ce57170000002d8660820000000000096748a6fffffff80000002d6976d5e0000000000a602ace010000000700000008000000006497987c000000006497987c000000006497987b0000002d86b46e600000000009bb3506000000006497987bc67940be40e0cc7ffaa1acb08ee3fab30955a197da1ec297ab133d4d43d86ee6ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace0000002bc5fcf02c0000000005e0e35afffffff80000002ba9780d7800000000053a9337010000001d0000001f000000006497987c000000006497987c000000006497987b0000002bc6164a940000000005fa3dc2000000006497987b8d7c0971128e8a4764e757dedb32243ed799571706af3a68ab6a75479ea524ff846ae1bdb6300b817cee5fdee2a6da192775030db5615b94a465f53bd40850b50000002bbadadfa0000000001493a88afffffff80000002ba3dcdb500000000010ac59da010000000900000009000000006497987c000000006497987c000000006497987b0000002bbadadfa0000000001493a88a000000006497987a543b71a4c292744d3fcf814a2ccda6f7c00f283d457f83aa73c41e9defae034ba0255134973f4fdf2f8f7808354274a3b1ebc6ee438be898d045e8b56ba1fe1300000000000000000000000000000000fffffff800000000000000000000000000000000000000000000000006000000006497987c000000006496162b0000000000000000000000000000000000000000000000000000000000000000";
        // fast forward chain and execute
        executeOffchainDelayedOrder(newBlock, priceUpdateData, address(userAccount));

        // since delta has increased old shorts pers < new short perps
        assertTrue(Math.abs(oldHedgedDelta) < Math.abs(newHedgedDelta));
        // check that the new perps amount is equal to
        assertEq(newHedgedDelta, userAccount.getCurrentPerpsAmount());
        // check that the leverage for perps on snx is in the ballpark range.
        // It might not be exact because of the time difference between submitting and executing order
        uint256 currentLeverage = uint256(userAccount.currentLeverage() * int(-1));
        assertApproxEqAbs(targetLeverage / 10 ** 16, currentLeverage / 10 ** 16, 2);
    }
}
