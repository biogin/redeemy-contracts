// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chiru-labs/contracts/ERC721A.sol";

import "./SharedTestSetup.sol";

import "./mocks/token/ERC20.sol";
import "./mocks/token/ERC721.sol";

contract TestAssetPool is SharedTestSetup {
    IRewardPoolV1 REWARD_POOL_ERC1155_REDEEM_TOKEN;
    IAssetPoolV1 ASSET_POOL_ERC1155;

    IRewardPoolV1 REWARD_POOL_ERC20_REDEEM_TOKEN;
    IAssetPoolV1 ASSET_POOL_ERC20;

    MockERC20 MOCK_ERC20;
    MockERC721 MOCK_ERC721;

    IERC1155RedeemTokenV1 ERC1155_REDEEM_TOKEN;
    IERC20RedeemTokenV1 ERC20_REDEEM_TOKEN;
    //    IERC721RedeemTokenV1 ERC721_REDEEM_TOKEN;

    function setUp() public {
        super.configure();

        vm.deal(mockOwner, 100 ether);

        vm.label(address(this), "TestRewardPool");

        vm.startPrank(mockOwner);
        address rewardPoolCloneERC1155 = REWARD_POOL_REGISTRY.createRewardPool(
            "reward pool factory customERC1155",
            IRewardPoolV1.RedeemMethod.CustomERC1155,
            address(0),
            1,
                mockOwner,
                new address [](0),
            "",
            "",
            "https://baseURI"
        );

        address rewardPoolCloneERC20 = REWARD_POOL_REGISTRY.createRewardPool(
            "reward pool factory redeem customERC20",
            IRewardPoolV1.RedeemMethod.CustomERC20,
            address(0),
            2000,
                mockOwner,
                new address [](0),
            "Custom token",
            "CT",
                "https://baseURI"
        );
        REWARD_POOL_ERC1155_REDEEM_TOKEN = IRewardPoolV1(rewardPoolCloneERC1155);
        REWARD_POOL_ERC20_REDEEM_TOKEN = IRewardPoolV1(rewardPoolCloneERC20);

        address [] memory transfers = new address[](1);
        transfers[0] = mockOwner;

        REWARD_POOL_ERC1155_REDEEM_TOKEN.addTransferrers(transfers);
        REWARD_POOL_ERC20_REDEEM_TOKEN.addTransferrers(transfers);

        ERC1155_REDEEM_TOKEN = IERC1155RedeemTokenV1(REWARD_POOL_ERC1155_REDEEM_TOKEN.getRedeemTokenContractAddress());
        ERC20_REDEEM_TOKEN = IERC20RedeemTokenV1(REWARD_POOL_ERC20_REDEEM_TOKEN.getRedeemTokenContractAddress());

        address assetPoolCloneERC1155 = REWARD_POOL_ERC1155_REDEEM_TOKEN.createAssetPool(1);

        ASSET_POOL_ERC1155 = IAssetPoolV1(assetPoolCloneERC1155);

        address assetPoolCloneERC20 = REWARD_POOL_ERC20_REDEEM_TOKEN.createAssetPool(2000);

        ASSET_POOL_ERC20 = IAssetPoolV1(assetPoolCloneERC20);

        MOCK_ERC20 = new MockERC20();
        MOCK_ERC721 = new MockERC721();

        MOCK_ERC20.mint(mockOwner, 200000000000000);
        MOCK_ERC721.mint(mockOwner, 1000);

        vm.stopPrank();
    }

    function testWithdrawAssets() public {
        // Setup initial balances and deposit assets
        (uint256 erc20Amount, uint256 erc721Amount, uint256 nativeTokenAmount) = _depositAssets(REWARD_POOL_ERC1155_REDEEM_TOKEN);

        // Prepare data for the withdrawAssets function
        address[] memory erc20ContractAddresses = new address[](1);
        IAssetPoolV1.AssetBox[][] memory erc20Boxes = new IAssetPoolV1.AssetBox[][](1);
        erc20ContractAddresses[0] = address(MOCK_ERC20);
        erc20Boxes[0] = _getErc20Boxes(mockOwner);

        address[] memory erc721ContractAddresses = new address[](1);
        uint256[][] memory erc721TokenIds = new uint256[][](1);
        erc721ContractAddresses[0] = address(MOCK_ERC721);
        erc721TokenIds[0] = _getErc721TokenIds();

        IAssetPoolV1.AssetBox[] memory nativeTokenBoxes = _getNativeTokenBoxes(mockOwner);

        //        vm.expectEmit(true, true, false, true);
        //        emit IAssetPoolV1.AssetsWithdrawn(ASSET_POOL_ERC1155.getRewardPool(), erc20ContractAddresses, erc20Boxes, erc721ContractAddresses, erc721TokenIds, nativeTokenBoxes);

        // Test withdrawing assets by the owner
        address owner = REWARD_POOL_ERC1155_REDEEM_TOKEN.getOwner();
        vm.prank(owner);
        ASSET_POOL_ERC1155.withdrawAssets(erc20ContractAddresses, erc20Boxes, erc721ContractAddresses, erc721TokenIds, nativeTokenBoxes);

        uint256 amount = 0;
        // Verify withdrawn ERC20 assets
        for (uint i = 0; i < erc20ContractAddresses.length; i++) {
            for (uint j = 0; j < erc20Boxes[i].length; j++) {
                amount += erc20Boxes[i][j].amountOrTokenId * erc20Boxes[i][j].numberOfCards;
            }

            assertEq(IERC20(erc20ContractAddresses[i]).balanceOf(address(ASSET_POOL_ERC1155)), erc20Amount - amount);
        }

        // Verify withdrawn ERC721 assets
        for (uint i = 0; i < erc721ContractAddresses.length; i++) {
            for (uint j = 0; j < erc721TokenIds[i].length; j++) {
                uint256 tokenId = erc721TokenIds[i][j];
                assertEq(IERC721(erc721ContractAddresses[i]).ownerOf(tokenId), owner);
            }
        }

        // Verify withdrawn native tokens
        amount = 0;
        for (uint i = 0; i < nativeTokenBoxes.length; i++) {
            amount += nativeTokenBoxes[i].amountOrTokenId * nativeTokenBoxes[i].numberOfCards;
        }

        assertEq(address(ASSET_POOL_ERC1155).balance, nativeTokenAmount - amount);
//        assertEq(ERC1155_REDEEM_TOKEN.balanceOf(address(ASSET_POOL_ERC1155), ASSET_POOL_ERC1155.id()), 0);

        // Test withdrawal by a non-owner
        address nonOwner = getRandomAddress();
        vm.prank(nonOwner);
        vm.expectRevert(bytes("AssetPoolV1: only owner allowed"));
        ASSET_POOL_ERC1155.withdrawAssets(erc20ContractAddresses, erc20Boxes, erc721ContractAddresses, erc721TokenIds, nativeTokenBoxes);
    }


    function testGetERC20Assets() public {
        // TODO
    }

    function testGetERC721Assets() public {
        // TODO

    }

    function testGetNativeTokenAssets() public {
        // TODO
    }

    function testRedeemTokenAmount() public {
        uint256 amount = 2;

        vm.expectRevert(bytes("AssetPoolV1: only owner allowed"));
        vm.prank(getRandomAddress());
        ASSET_POOL_ERC1155.setRedeemTokenAmount(amount);

        vm.startPrank(mockOwner);

        vm.expectRevert(bytes("AssetPoolV1: amount should be more than zero"));
        ASSET_POOL_ERC1155.setRedeemTokenAmount(0);

        ASSET_POOL_ERC1155.setRedeemTokenAmount(amount);

        assertEq(ASSET_POOL_ERC1155.getRedeemTokenAmount(), amount);

        vm.stopPrank();
    }

    function testRedeemAssetAndFulfillRedeemAssetERC1155() public {
        (uint256 erc20Amount,uint256 erc721Amount,uint256 nativeTokenAmount) = _depositAssets(REWARD_POOL_ERC1155_REDEEM_TOKEN);

        address randomUser = getRandomAddress();
        uint256 poolId = ASSET_POOL_ERC1155.id();
        uint256 amountOfAssets = 2;

        // TODO
        //         Test minting redeem tokens to a random user and transferring them
        //        _testMintRedeemTokens(poolId, randomUser, amountOfAssets);
        //
        //        // Test redeeming assets with various constraints and validations
        //        _testRedeemAssetConstraints(randomUser, amountOfAssets);
        //
        //        // Test redeeming assets and fulfilling the redemption
        //        _testRedeemFulfillAsset(poolId, randomUser, amountOfAssets, erc20Amount, erc721Amount, nativeTokenAmount);
        //
        //        // Test redeeming and fulfilling all assets
        //        _testRedeemFulfillAllAssets(randomUser, erc20Amount, erc721Amount, nativeTokenAmount);

        vm.prank(mockOwner);
        vm.expectRevert(bytes("RedeemTokenV1: only asset pool allowed with correct asset pool id"));
        ERC1155_REDEEM_TOKEN.mint(randomUser, poolId, amountOfAssets, '');

        _transferRedeemToken(randomUser, amountOfAssets);
        assertEq(ERC1155_REDEEM_TOKEN.balanceOf(randomUser, poolId), amountOfAssets);

        vm.startPrank(randomUser);

        vm.expectRevert(IAssetPoolV1.RedeemAtLeastOneAsset.selector);
        ASSET_POOL_ERC1155.redeemAsset(0);

        uint256 max = REWARD_POOL_ERC1155_REDEEM_TOKEN.getMaxNumberOfRewardsPerTx();
        vm.expectRevert(IAssetPoolV1.RedeemMoreThanMaxAmount.selector);
        ASSET_POOL_ERC1155.redeemAsset(max + 1);

        vm.expectRevert(IAssetPoolV1.InsufficientBalance.selector);
        ASSET_POOL_ERC1155.redeemAsset(amountOfAssets + 1);

        uint256 total = ASSET_POOL_ERC1155.getTotalNumberOfAssets();

        ASSET_POOL_ERC1155.redeemAsset(amountOfAssets);

        assertEq(ERC1155_REDEEM_TOKEN.balanceOf(randomUser, poolId), 0);

        assertEq(ASSET_POOL_ERC1155.getTotalNumberOfAssets(), total - amountOfAssets);

        vm.stopPrank();

        uint256 requestId = 1;
        uint256 [] memory randomWords = getRandomWords();

        for (uint i = 0; i < amountOfAssets; ++i) {
            vm.startPrank(REWARD_POOL_ERC1155_REDEEM_TOKEN.getVRFConsumer());
            (
            IAssetPoolV1.AssetType assetType,
            address contractAddress,
            uint256 amountOrTokenId
            ) = ASSET_POOL_ERC1155.fulfillRedeemAsset(requestId, randomUser, randomWords);
            vm.stopPrank();

            if (assetType == IAssetPoolV1.AssetType.ERC721) {
                --erc721Amount;
                assertEq(IERC721(contractAddress).balanceOf(address(ASSET_POOL_ERC1155)), erc721Amount);
                assertEq(IERC721(contractAddress).ownerOf(amountOrTokenId), randomUser);
            }
            if (assetType == IAssetPoolV1.AssetType.ERC20) {
                erc20Amount -= amountOrTokenId;
                assertEq(IERC20(contractAddress).balanceOf(address(ASSET_POOL_ERC1155)), erc20Amount);
            }
            if (assetType == IAssetPoolV1.AssetType.NativeToken) {
                nativeTokenAmount -= amountOrTokenId;
                assertEq(contractAddress.balance, nativeTokenAmount);
            }
        }

        total = ASSET_POOL_ERC1155.getTotalNumberOfAssets();
        uint256 totalPrev = total;

        _transferRedeemToken(randomUser, total);

        vm.startPrank(randomUser);
        while (total > max) {
            ASSET_POOL_ERC1155.redeemAsset(max);

            total -= max;
        }

        if (total > 0) {
            ASSET_POOL_ERC1155.redeemAsset(total);
        }

        vm.stopPrank();

        assertEq(ASSET_POOL_ERC1155.getTotalNumberOfAssets(), 0);

        vm.startPrank(REWARD_POOL_ERC1155_REDEEM_TOKEN.getVRFConsumer());
        for (uint i = 0; i < totalPrev; ++i) {
            ASSET_POOL_ERC1155.fulfillRedeemAsset(requestId, randomUser, randomWords);
        }
        vm.stopPrank();

        address [] memory contractAddresses = ASSET_POOL_ERC1155.getContractsByAssetType(IAssetPoolV1.AssetType.ERC20);
        for (uint i = 0; i < contractAddresses.length; ++i) {
            assertEq(ASSET_POOL_ERC1155.getERC20Assets(contractAddresses[i]).length, 0);
        }

        contractAddresses = ASSET_POOL_ERC1155.getContractsByAssetType(IAssetPoolV1.AssetType.ERC721);
        for (uint i = 0; i < contractAddresses.length; ++i) {
            assertEq(ASSET_POOL_ERC1155.getERC721Assets(contractAddresses[i]).length, 0);
        }

        contractAddresses = ASSET_POOL_ERC1155.getContractsByAssetType(IAssetPoolV1.AssetType.NativeToken);
        for (uint i = 0; i < contractAddresses.length; ++i) {
            assertEq(ASSET_POOL_ERC1155.getNativeTokenAssets().length, 0);
        }
    }

    function testRedeemAssetAndFulfillRedeemAssetERC20() public {
        (uint256 erc20Amount, uint256 erc721Amount, uint256 nativeTokenAmount) = _depositAssets(REWARD_POOL_ERC20_REDEEM_TOKEN);

        address randomUser = getRandomAddress();
        uint256 amountOfTokens = 1;

        assertEq(ERC20_REDEEM_TOKEN.balanceOf(randomUser), 0);

        uint256 exactMintAmount = amountOfTokens * ASSET_POOL_ERC20.getRedeemTokenAmount();

        vm.prank(mockOwner);
        vm.expectRevert(bytes("RedeemTokenV1: only asset pool allowed"));
        ERC20_REDEEM_TOKEN.mint(randomUser, exactMintAmount);

        vm.startPrank(mockOwner);
        ASSET_POOL_ERC20.transferRedeemTokenNumber(randomUser, amountOfTokens);
        vm.stopPrank();

        vm.startPrank(randomUser);

        vm.expectRevert(IAssetPoolV1.RedeemAtLeastOneAsset.selector);
        ASSET_POOL_ERC20.redeemAsset(0);

        uint256 max = REWARD_POOL_ERC1155_REDEEM_TOKEN.getMaxNumberOfRewardsPerTx();
        vm.expectRevert(IAssetPoolV1.RedeemMoreThanMaxAmount.selector);
        ASSET_POOL_ERC20.redeemAsset(max + 1);

        vm.expectRevert(IAssetPoolV1.InsufficientBalance.selector);
        ASSET_POOL_ERC20.redeemAsset(amountOfTokens + 1);

        ASSET_POOL_ERC20.redeemAsset(1);

        assertEq(ERC20_REDEEM_TOKEN.balanceOf(randomUser), 0);

        vm.stopPrank();

        uint256 requestId = 1;
        uint256 [] memory randomWords = getRandomWords();

        vm.startPrank(REWARD_POOL_ERC1155_REDEEM_TOKEN.getVRFConsumer());
        (
        IAssetPoolV1.AssetType assetType,
        address contractAddress,
        uint256 amountOrTokenId
        ) = ASSET_POOL_ERC20.fulfillRedeemAsset(requestId, randomUser, randomWords);
        vm.stopPrank();

        if (assetType == IAssetPoolV1.AssetType.ERC721) {
            assertEq(IERC721(contractAddress).balanceOf(address(ASSET_POOL_ERC20)), erc721Amount - 1);
        }
        if (assetType == IAssetPoolV1.AssetType.ERC20) {
            assertEq(IERC20(contractAddress).balanceOf(address(ASSET_POOL_ERC20)), erc20Amount - amountOrTokenId);
        }
        if (assetType == IAssetPoolV1.AssetType.NativeToken) {
            assertEq(contractAddress.balance, nativeTokenAmount - amountOrTokenId);
        }
    }

    function _depositAssets(IRewardPoolV1 pool) public returns (uint256 erc20Balance, uint256 erc721Balance, uint256 nativeTokenBalance) {
        vm.startPrank(mockOwner);

        uint256 ERC20_AMOUNT = 88100;
        uint256 ERC721_AMOUNT = 12;
        uint256 NATIVE_TOKEN_AMOUNT = 1 ether;

        address [] memory erc20ContractAddresses = new address [](1);
        uint256 [] memory erc20Amounts = new uint256 [](1);
        IAssetPoolV1.AssetBox [][] memory erc20Boxes = new IAssetPoolV1.AssetBox[][](1);
        erc20Boxes[0] = new IAssetPoolV1.AssetBox[](9);
        erc20ContractAddresses[0] = address(MOCK_ERC20);
        erc20Amounts[0] = ERC20_AMOUNT;

        // ERC721 TOKEN -----------------------------------
        address [] memory erc721ContractAddresses = new address [](1);
        uint256 [][] memory erc721TokenIds = new uint256[][](1);
        erc721ContractAddresses[0] = address(MOCK_ERC721);
        erc721TokenIds[0] = new uint256[](ERC721_AMOUNT);

        for (uint i = 0; i < ERC721_AMOUNT; ++i) {
            erc721TokenIds[0][i] = i;
        }

        // ERC20 TOKEN -----------------------------------
        erc20Boxes[0][0] = IAssetPoolV1.AssetBox({
        depositer : mockOwner,
        assetType : IAssetPoolV1.AssetType.ERC20,
        numberOfCards : 5,
        amountOrTokenId : 300
        });

        erc20Boxes[0][1] = IAssetPoolV1.AssetBox({
        depositer : mockOwner,
        assetType : IAssetPoolV1.AssetType.ERC20,
        numberOfCards : 10,
        amountOrTokenId : 200
        });

        erc20Boxes[0][2] = IAssetPoolV1.AssetBox({
        depositer : mockOwner,
        assetType : IAssetPoolV1.AssetType.ERC20,
        numberOfCards : 20,
        amountOrTokenId : 150
        });

        erc20Boxes[0][3] = IAssetPoolV1.AssetBox({
        depositer : mockOwner,
        assetType : IAssetPoolV1.AssetType.ERC20,
        numberOfCards : 30,
        amountOrTokenId : 120
        });

        erc20Boxes[0][4] = IAssetPoolV1.AssetBox({
        depositer : mockOwner,
        assetType : IAssetPoolV1.AssetType.ERC20,
        numberOfCards : 100,
        amountOrTokenId : 100
        });

        erc20Boxes[0][5] = IAssetPoolV1.AssetBox({
        depositer : mockOwner,
        assetType : IAssetPoolV1.AssetType.ERC20,
        numberOfCards : 150,
        amountOrTokenId : 80
        });

        erc20Boxes[0][6] = IAssetPoolV1.AssetBox({
        depositer : mockOwner,
        assetType : IAssetPoolV1.AssetType.ERC20,
        numberOfCards : 200,
        amountOrTokenId : 60
        });

        erc20Boxes[0][7] = IAssetPoolV1.AssetBox({
        depositer : mockOwner,
        assetType : IAssetPoolV1.AssetType.ERC20,
        numberOfCards : 600,
        amountOrTokenId : 40
        });

        erc20Boxes[0][8] = IAssetPoolV1.AssetBox({
        depositer : mockOwner,
        assetType : IAssetPoolV1.AssetType.ERC20,
        numberOfCards : 1000,
        amountOrTokenId : 20
        });


        // NATIVE TOKEN -------------------------------------
        IAssetPoolV1.AssetBox [] memory nativeTokenBoxes = new IAssetPoolV1.AssetBox[](2);

        nativeTokenBoxes[0] = IAssetPoolV1.AssetBox({
        depositer : mockOwner,
        assetType : IAssetPoolV1.AssetType.NativeToken,
        numberOfCards : 2,
        amountOrTokenId : (1 ether) / 4
        });

        nativeTokenBoxes[1] = IAssetPoolV1.AssetBox({
        depositer : mockOwner,
        assetType : IAssetPoolV1.AssetType.NativeToken,
        numberOfCards : 4,
        amountOrTokenId : (1 ether) / 8
        });

        IRewardPoolV1.RedeemMethod method = pool.getRedeemMethod();
        if (method == IRewardPoolV1.RedeemMethod.CustomERC1155) {
            _approve(address(ASSET_POOL_ERC1155), ERC20_AMOUNT);

            ASSET_POOL_ERC1155.depositAssets{value : NATIVE_TOKEN_AMOUNT}(
                erc20ContractAddresses,
                erc20Boxes,

                erc721ContractAddresses,
                erc721TokenIds,

                nativeTokenBoxes
            );
        } else if (method == IRewardPoolV1.RedeemMethod.CustomERC20) {
            _approve(address(ASSET_POOL_ERC20), ERC20_AMOUNT);

            ASSET_POOL_ERC20.depositAssets{value : NATIVE_TOKEN_AMOUNT}(
                erc20ContractAddresses,
                erc20Boxes,

                erc721ContractAddresses,
                erc721TokenIds,

                nativeTokenBoxes
            );
        }

        vm.stopPrank();

        return (ERC20_AMOUNT, ERC721_AMOUNT, NATIVE_TOKEN_AMOUNT);
    }

    function _approve(address pool, uint256 erc20Amount) private {
        MOCK_ERC721.setApprovalForAll(pool, true);

        MOCK_ERC20.approve(pool, erc20Amount);
    }

    function _transferRedeemToken(address to, uint256 number) private {
        vm.startPrank(mockOwner);
        ASSET_POOL_ERC1155.transferRedeemTokenNumber(to, number);
        vm.stopPrank();
    }


    // Helper functions to get the deposited asset data
    function _getErc20Boxes(address depositer) internal pure returns (IAssetPoolV1.AssetBox[] memory) {
        IAssetPoolV1.AssetBox[] memory erc20Boxes = new IAssetPoolV1.AssetBox[](9);

        erc20Boxes[0] = IAssetPoolV1.AssetBox({depositer : depositer, assetType : IAssetPoolV1.AssetType.ERC20, numberOfCards : 5, amountOrTokenId : 300});
        erc20Boxes[1] = IAssetPoolV1.AssetBox({depositer : depositer, assetType : IAssetPoolV1.AssetType.ERC20, numberOfCards : 10, amountOrTokenId : 200});
        erc20Boxes[2] = IAssetPoolV1.AssetBox({depositer : depositer, assetType : IAssetPoolV1.AssetType.ERC20, numberOfCards : 20, amountOrTokenId : 150});
        erc20Boxes[3] = IAssetPoolV1.AssetBox({depositer : depositer, assetType : IAssetPoolV1.AssetType.ERC20, numberOfCards : 30, amountOrTokenId : 120});
        erc20Boxes[4] = IAssetPoolV1.AssetBox({depositer : depositer, assetType : IAssetPoolV1.AssetType.ERC20, numberOfCards : 100, amountOrTokenId : 100});
        erc20Boxes[5] = IAssetPoolV1.AssetBox({depositer : depositer, assetType : IAssetPoolV1.AssetType.ERC20, numberOfCards : 150, amountOrTokenId : 80});
        erc20Boxes[6] = IAssetPoolV1.AssetBox({depositer : depositer, assetType : IAssetPoolV1.AssetType.ERC20, numberOfCards : 200, amountOrTokenId : 60});
        erc20Boxes[7] = IAssetPoolV1.AssetBox({depositer : depositer, assetType : IAssetPoolV1.AssetType.ERC20, numberOfCards : 600, amountOrTokenId : 40});
        erc20Boxes[8] = IAssetPoolV1.AssetBox({depositer : depositer, assetType : IAssetPoolV1.AssetType.ERC20, numberOfCards : 1000, amountOrTokenId : 20});

        return erc20Boxes;
    }

    function _getErc721TokenIds() internal pure returns (uint256[] memory) {
        uint256[] memory erc721TokenIds = new uint256[](12);

        for (uint i = 0; i < 12; ++i) {
            erc721TokenIds[i] = i;
        }

        return erc721TokenIds;
    }

    function _getNativeTokenBoxes(address depositer) internal pure returns (IAssetPoolV1.AssetBox[] memory) {
        IAssetPoolV1.AssetBox[] memory nativeTokenBoxes = new IAssetPoolV1.AssetBox[](2);

        nativeTokenBoxes[0] = IAssetPoolV1.AssetBox({depositer : depositer, assetType : IAssetPoolV1.AssetType.NativeToken, numberOfCards : 2, amountOrTokenId : (1 ether) / 4});
        nativeTokenBoxes[1] = IAssetPoolV1.AssetBox({depositer : depositer, assetType : IAssetPoolV1.AssetType.NativeToken, numberOfCards : 4, amountOrTokenId : (1 ether) / 8});

        return nativeTokenBoxes;
    }

}
