// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import "./SharedTestSetup.sol";

contract TestRewardPoolRegistry is SharedTestSetup {
    event RewardPoolCreated(address indexed owner, address pool);

    event NameChanged(string);

    function setUp() public {
        super.configure();

        vm.label(address(this), "TestRewardPoolRegistry");
    }

    function testCreateRewardPool() public {
        vm.startPrank(mockOwner);

        address randomUser = getRandomAddress();

        address [] memory admins = new address [](1);

        admins[0] = randomUser;

        address rewardPoolClone = REWARD_POOL_REGISTRY.createRewardPool(
            "reward pool factory",
            IRewardPoolV1.RedeemMethod.CustomERC1155,
            address(0),
            1,
            mockOwner,
            admins,
            "",
            "",
            ""
        );

        assertEq(uint256(IRewardPoolV1(rewardPoolClone).getRedeemMethod()), uint256(IRewardPoolV1.RedeemMethod.CustomERC1155));

        address [] memory pools = REWARD_POOL_REGISTRY.getRewardPoolsByAddress(mockOwner);

        assertEq(pools.length, 1);
        assertEq(pools[0], rewardPoolClone);

        assertEq(admins.length, IRewardPoolV1(rewardPoolClone).getAdmins().length);

        assertEq(admins[0], IRewardPoolV1(rewardPoolClone).getAdmins()[0]);

        address owner = REWARD_POOL_REGISTRY.getRewardPoolOwner(rewardPoolClone);

        assertEq(owner, mockOwner);

        address [] memory assetPools = IRewardPoolV1(rewardPoolClone).getAssetPools();

        assertEq(assetPools.length, 1);

        vm.stopPrank();
    }

    function testCreateRewardPoolWithFee() public {
        vm.startPrank(mockOwner);

        vm.deal(mockOwner, 1 ether);

        address randomUser = getRandomAddress();

        address [] memory admins = new address [](1);

        admins[0] = randomUser;

        vm.expectRevert(IRewardPoolRegistryV1.InvalidFeeAmountSent.selector);
        address rewardPoolClone = REWARD_POOL_REGISTRY_WITH_FEE.createRewardPool(
            "reward pool factory",
            IRewardPoolV1.RedeemMethod.CustomERC1155,
            address(0),
            1,
            mockOwner,
            admins,
            "",
            "",
            ""
        );

        vm.expectRevert(IRewardPoolRegistryV1.InvalidFeeAmountSent.selector);
        rewardPoolClone = REWARD_POOL_REGISTRY_WITH_FEE.createRewardPool{value : 0.5 ether}(
            "reward pool factory",
            IRewardPoolV1.RedeemMethod.CustomERC1155,
            address(0),
            1,
            mockOwner,
            admins,
            "",
            "",
            ""
        );

        rewardPoolClone = REWARD_POOL_REGISTRY_WITH_FEE.createRewardPool{value : REWARD_POOL_REGISTRY_WITH_FEE.getRewardPoolCreationFee()}(
            "reward pool factory",
            IRewardPoolV1.RedeemMethod.CustomERC1155,
            address(0),
            1,
            mockOwner,
            admins,
            "",
            "",
            ""
        );

    }

    function testCreateRewardPoolEmptyName() public {
        vm.startPrank(mockOwner);

        address randomUser = getRandomAddress();

        address[] memory admins = new address[](1);
        admins[0] = randomUser;

        vm.expectRevert(IRewardPoolRegistryV1.InvalidName.selector);
        address rewardPoolClone = REWARD_POOL_REGISTRY.createRewardPool(
            "",
            IRewardPoolV1.RedeemMethod.CustomERC1155,
            address(0),
            1,
            mockOwner,
            admins,
            "",
            "",
            ""
        );

        vm.stopPrank();
    }

    function testCreateRewardPoolExistingName() public {
        vm.startPrank(mockOwner);

        address randomUser = getRandomAddress();

        address[] memory admins = new address[](1);
        admins[0] = randomUser;

        // Create the first reward pool
        address rewardPoolClone = REWARD_POOL_REGISTRY.createRewardPool(
            "existing_name",
            IRewardPoolV1.RedeemMethod.CustomERC1155,
            address(0),
            1,
            mockOwner,
            admins,
            "",
            "",
            ""
        );

        // Try to create a reward pool with the same name
        vm.expectRevert(IRewardPoolRegistryV1.NameAlreadyExists.selector);
        rewardPoolClone = REWARD_POOL_REGISTRY.createRewardPool(
            "existing_name",
            IRewardPoolV1.RedeemMethod.CustomERC1155,
            address(0),
            1,
            mockOwner,
            admins,
            "",
            "",
            ""
        );

        vm.stopPrank();
    }

    function testUpdateRewardPoolName() public {
        vm.startPrank(mockOwner);

        address randomUser = getRandomAddress();

        address[] memory admins = new address[](1);
        admins[0] = randomUser;

        // Create the reward pool
        address rewardPoolClone = REWARD_POOL_REGISTRY.createRewardPool(
            "initial_name",
            IRewardPoolV1.RedeemMethod.CustomERC1155,
            address(0),
            1,
            mockOwner,
            admins,
            "",
            "",
            ""
        );

        string memory initial_name = IRewardPoolV1(rewardPoolClone).name();
        assertEq(initial_name, "initial_name");

        // Update the reward pool name
        vm.expectEmit(false, false, false, true);
        emit NameChanged("updated_name");
        REWARD_POOL_REGISTRY.setNewRewardPoolName(rewardPoolClone, "updated_name");

        // Check if the name is updated
        string memory updatedName = IRewardPoolV1(rewardPoolClone).name();
        assertEq(updatedName, "updated_name");

        vm.stopPrank();
    }

    function testSetRevenueWallet() public {
        vm.startPrank(mockOwner);

        address newRevenueWallet = getRandomAddress();

        // Set a new revenue wallet
        REWARD_POOL_REGISTRY.setRevenueWallet(newRevenueWallet);

        // Check if the revenue wallet is updated
        address updatedRevenueWallet = REWARD_POOL_REGISTRY.revenueWallet();
        assertEq(updatedRevenueWallet, newRevenueWallet);

        vm.stopPrank();
    }

    function testSetRewardPoolCreationFee() public {
        vm.startPrank(mockOwner);

        uint256 newFee = 2 ether;

        // Set a new reward pool creation fee
        REWARD_POOL_REGISTRY.setRewardPoolCreationFee(newFee);

        // Check if the fee is updated
        uint256 updatedFee = REWARD_POOL_REGISTRY.getRewardPoolCreationFee();
        assertEq(updatedFee, newFee);

        vm.stopPrank();
    }

    function testCreatePaymaster() public {
        vm.startPrank(mockOwner);

        // Create the paymaster
        REWARD_POOL_REGISTRY.createPaymaster();

        // Check if the paymaster is created
        address paymaster = REWARD_POOL_REGISTRY.getPaymaster(mockOwner);
        assert(paymaster != address(0));

        vm.stopPrank();
    }
}
