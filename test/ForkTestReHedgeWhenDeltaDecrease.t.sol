// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {Math} from "@lyrafinance/protocol/contracts/libraries/Math.sol";
import "./BaseHedgingTestHelper.sol";

contract ForkTestReHedgeWhenDeltaDecrease is BaseHedgingTestHelper {
    function setUp() external {
        targetBlock = 108296416; // Aug-16-2023 01:13:29 PM +UTC
        vm.rollFork(targetBlock - 5);
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
                targetLeverage: targetLeverage,
                priceDeltaBuffer: 1050000000000000000
            })
        );
        vm.stopPrank();

        vm.prank(user);
        userAccount = Account_(accountFactory.newAccount());
        fundAccount(user);
        vm.makePersistent(address(accountImplementation), address(accountFactory), address(userAccount));
        vm.makePersistent(user);

        strikeID = 262;
        optionsAmount = 2e18;
        setupBuyHedgeCall();
    }

    function setupBuyHedgeCall() internal {
        vm.startPrank(user);
        usdc.transfer(address(userAccount), 50000e6);
        sUSD.transfer(address(userAccount), 50000e18);
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
            memory priceUpdateData = hex"01000000030d00e2a6214ffe3eb8b19894f09190f0a844907b57db3b4c9948b8984cb107129072646428d520c8b830421a772a667175a07b9fbc5800a3bf66bedf73fbe9b16b930102618e7e131deaf9b803539de79efab1df1cb0ce2e746b618170b27fef2083f80f3ad9455f72d5bdceeaed313cfbe3e46860c370d0870768a3e9febe467a42e2c0000370290dbe9f07a812141f018107590fb4c3dc81b0e870556049b27568b400876d7aaf16eaf45275f82d5a08d6aced49dfaf5692b6e102899a367fab54b9f9f6ec01068b12543fed625237041e9f95029e249543122ffd4c5a75c08a14370f2ef420fc6d2dd26846584daced6c57fadab464fe1a7bae55a09ed53050c525e99e3dfc7c00097d4a54b5d092a3087ac7b3bc2c4d5e5b91ebb2eec40306a3c0627eaf6a6289183d56b81dba7b37fa4af59181a2411de7e90c86f3209bcd30b709ce81fc193864010ab5b368b4e7bddd641509f6a0ced95eb5237df4804e1eccf51c02c1023896f7d46ca6ff235b47c52747ab1a0ff08599e46d36e29f6e5fc8318a2ea4848ed32885010b89cb0f6ad252f408eb8034aded78476dc476a81c20a093bccd43f87e3cdb671f19bff48fe10626fc645a91f4f025dadc65b09d43968781c54e063436102b3fb5000c0f17f9316937ec1a52284efe2385ccf55a8c43ee752de13307397bdc9553f44958ef38d44ea51ac2398168f2083e3abaf644cd2f94009d9d8a00bb75677198f1010d357fda1999bed9f6354a4a4667cc0b119d777150d4bbc15a74e87cbf01b02bb823297df724aa618deb63f2ab1bbf7fedcd83eb2048a0a3c77476e4e5cde85eb0010e66d8e4972530f20a1804772d1b4c9a98ae443ae47beb1ef8dfad3b610c21485e62ffe9aa3f2592b2fa22ca0c7e45bf6f8ab2d674f65f1dee51be145920997bb2000fe07934352dc5b85f15d066eb17b212fa661b22608388d511f03f74420cb9dcb460a211fa5538e1387033837c6803bbbce2917247c981dc96c6f57cc25a7e8e86011070b2c4b474e1ab576eabfae005cadc076b7db9a171f80565982b949f6d88e99a25c00f490a04ff82177a16459db725a2c1b1102b6f337146ef78710e01f7e7350012794607e1dccf9e7bfbd3e4baf97076b2c08f355a43de2c5f4a89401f3f59f2f02bf79342d89cd334e082a287246676ffa02d481a4999a6ecb03cfcd3c564afe90064dccb7500000000001af8cd23c2ab91237730770bbea08d61005cdda0984348f3f6eecb559638c0bba000000000238b73c60150325748000300010001020005009d04028fba493a357ecde648d51375a445ce1cb9681da1ea11e562b53522a5d3877f981f906d7cfe93f618804f1de89e0199ead306edc022d3230b3e8305f391b00000002a5f8e6911000000000f393ebffffffff80000002a64e29b98000000000fa7c811010000000d0000000f0000000064dccb750000000064dccb750000000064dccb740000002a5f8e6911000000000f393ebf0000000064dccb74e6c020c1a15366b779a8c870e065023657c88c82b82d58a9fe856896a4034b0415ecddd26d49e1a8f1de9376ebebc03916ede873447c1255d2d5891b92ce57170000002c5d2a259a000000000fac207dfffffff80000002c5e717980000000000fd69a33010000000a0000000b0000000064dccb750000000064dccb740000000064dccb740000002c5d2a259a000000000fac207d0000000064dccb74c67940be40e0cc7ffaa1acb08ee3fab30955a197da1ec297ab133d4d43d86ee6ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace0000002a6d052786000000000b50695afffffff80000002a70be4c50000000000a066c5c010000001f000000200000000064dccb750000000064dccb750000000064dccb740000002a6d052786000000000acfa1220000000064dccb748d7c0971128e8a4764e757dedb32243ed799571706af3a68ab6a75479ea524ff846ae1bdb6300b817cee5fdee2a6da192775030db5615b94a465f53bd40850b50000002a6f7fa7eb000000000b3bfb3dfffffff80000002a71fdb5d8000000000d7f653a010000000d0000000d0000000064dccb750000000064dccb750000000064dccb740000002a6f7fa7eb000000000b3bfb3d0000000064dccb74543b71a4c292744d3fcf814a2ccda6f7c00f283d457f83aa73c41e9defae034ba0255134973f4fdf2f8f7808354274a3b1ebc6ee438be898d045e8b56ba1fe1300000000000000000000000000000000fffffff8000000000000000000000000000000000000000002000000080000000064dccb750000000064dccb740000000000000000000000000000000000000000000000000000000000000000";
        // fast forward chain and execute
        executeOffchainDelayedOrder(targetBlock, priceUpdateData, address(userAccount));
        // check that the hedged delta amount
        assertEq(hedgedDelta, userAccount.getCurrentPerpsAmount());
        // check that the leverage for perps on snx is in the ballpark range.
        // It might not be exact because of the time difference between submitting and executing order
        uint256 currentLeverage = uint256(userAccount.currentLeverage() * int(-1));
        assertApproxEqAbs(targetLeverage / 10 ** 16, currentLeverage / 10 ** 16, 2);
    }

    function testReHedgewhenDeltaDrop() external {
        // foundry has some weird bugs for the optimism fork.
        // if the sUSD balance is not checked here than forge resets it to 0.
        assertTrue(sUSD.balanceOf(address(userAccount)) > 0);
        assertTrue(usdc.balanceOf(address(userAccount)) > 0);

        int oldHedgedDelta = userAccount.getCurrentPerpsAmount();
        uint256 newTargetBlock = 108385761; // Aug-18-2023 02:51:39 PM +UTC

        vm.rollFork(newTargetBlock - 5);
        // After rolling the chain, the position opened by userAccount gets overwritten.
        // This is because the positionID opened by the test was actually opened and owned by another address onchain
        // Fake this by buying an option with same strikeID and Size to test reHedging logic.
        assertEq(ethOptionToken.getOwnerPositions(address(userAccount)).length, 0);
        buyCallOption();

        vm.startPrank(user);
        userAccount.reHedgeDelta();

        int256 newDelta = userAccount.getDelta(strikeID);
        assertTrue(uint256(oldDelta) > uint256(newDelta));

        int256 newHedgedDelta = (int(optionsAmount) * newDelta * int(-1)) / 1e18;
        bytes
            memory priceUpdateData = hex"01000000030d00778741bc51330bc8b780b02eef017949ab55ec35658165895c5572f4db00e1362b7ac7596ca73df1decbef1c6ddd47f77314d4cd8a7e73cb4beb221db4cafa960101c55e6467e452c874bd97178f05f1f30d78b78dc24fdbc9b030f40cb5ec00acce4b07f0f4922bd9f63ad2a30923c3da9c38bd69e6a1b643231415331b0cf20a9b000274e6292586d1efcaae672fc1fd9e73fa24c46ac521ab29b5daac7905bbba9647172308f8f6e24c236f4a6d0c4ddf36cb9a46f550d7f53838246c78482953deca00033eecfeebef721146cddce10b5d171605a58d0ffd23ee20e582060895f74c6291225550cd4d098c8c4a2215daebf4591369a948e829c06d8307b8b89234ba47f400049f69eac98014919f829e19f28bd13a11e7ee896e06854e0b74c676bc36d3df4e7dc38ac0d05b44c526c379bfdc07110999d9db945342c07dea5eb581c30b32ae000a0cd67efa1f4fc7062f990eb3d843d4425751d30537a56c80b90089e61042ea4515ecd82a2d0be76dce4514d5f410077282994ba959eade7db178026f831a6393010b7e7ecdc1eff2c65d6f823abe6704418f31099d2d3511d39d48e0d45bae00e88c1333f3d1f5ed0bbd9b3cd8e698e3ce55721d5d953aa1d6eb870929aefd095456010d687eb418d3aa9c8dff6ec53283e73d4dbcbe4f0a1b2a9294fd6ed20a61afad7d65f433ae973d1fdb22aaa95c70c0ed9f6cb9b2adc472e1e9e631d7f6b0a39067000e5da6108460856be6d32ff065a2701b34da266e788582a40d8a10c9a78e4859f567fe0ade33c49a8b9e6d9a7c46eaa00d843e894f1dd7e44159209f014dd96b6e000f6a4297738e222b086aa3e4a74137cc8e518ab7fea482a7d7c7a4f71c845b12fa359b675f4221401e532ca8e16df646b7d193e313d8d236e08c73803eed699c42001041cc772e9e5d40fa7fbd6747577fbd3f541b3b0650d682445270e91b3201c60150eb82d9b1f4eb966c31a31fc5c8358378940d96605e7948c528a243caf44d39001158617e5644915e4407e9f403237e79f33ab17614b303379d2d51eb27de4bef4649f3bee262b5d523ef45cec2f9c95cae8e563d1c998f34e02d80e15c454f236500123a00cbac6ec95c9ba9b0631e18a0e40c36a6446bf163c837aed9a47cdb0c55fc5af5c718faba4077f8cad1fd6ac45b8db31eb9a18f76d9116d8652989cc32a700164df857900000000001af8cd23c2ab91237730770bbea08d61005cdda0984348f3f6eecb559638c0bba00000000023cd0d1b0150325748000300010001020005009d04028fba493a357ecde648d51375a445ce1cb9681da1ea11e562b53522a5d3877f981f906d7cfe93f618804f1de89e0199ead306edc022d3230b3e8305f391b000000026d40a12e10000000007f1dc58fffffff800000026f2b217b800000000096f95a0010000000c0000000f0000000064df85790000000064df85790000000064df857800000026d40a12e10000000007f1dc580000000064df8577e6c020c1a15366b779a8c870e065023657c88c82b82d58a9fe856896a4034b0415ecddd26d49e1a8f1de9376ebebc03916ede873447c1255d2d5891b92ce571700000028a00309bc000000000e149187fffffff800000028c462f740000000000d30b22c010000000a0000000b0000000064df85790000000064df85780000000064df857700000028a00309bc000000000e1491870000000064df8577c67940be40e0cc7ffaa1acb08ee3fab30955a197da1ec297ab133d4d43d86ee6ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace00000026d69ef960000000000564eba0fffffff800000026fb64693800000000054dccde010000001f000000200000000064df85790000000064df85790000000064df857800000026d82412c00000000004c4b4000000000064df85788d7c0971128e8a4764e757dedb32243ed799571706af3a68ab6a75479ea524ff846ae1bdb6300b817cee5fdee2a6da192775030db5615b94a465f53bd40850b500000026d22b48560000000011307eaafffffff800000026fadde7a00000000014617506010000000c0000000d0000000064df85790000000064df85790000000064df857800000026d31f761c00000000103c50e40000000064df8577543b71a4c292744d3fcf814a2ccda6f7c00f283d457f83aa73c41e9defae034ba0255134973f4fdf2f8f7808354274a3b1ebc6ee438be898d045e8b56ba1fe1300000000000000000000000000000000fffffff8000000000000000000000000000000000000000003000000080000000064df85790000000064df85770000000000000000000000000000000000000000000000000000000000000000";
        // fast forward chain and execute
        executeOffchainDelayedOrder(newTargetBlock, priceUpdateData, address(userAccount));

        // since delta has reduced old shorts pers > new short perps
        assertTrue(Math.abs(oldHedgedDelta) > Math.abs(newHedgedDelta));
        // check that the new perps amount is equal to
        assertEq(newHedgedDelta, userAccount.getCurrentPerpsAmount());
        // check that the leverage for perps on snx is in the ballpark range.
        // It might not be exact because of the time difference between submitting and executing order
        uint256 currentLeverage = uint256(userAccount.currentLeverage() * int(-1));
        assertApproxEqAbs(targetLeverage / 10 ** 16, currentLeverage / 10 ** 16, 2);
    }
}
