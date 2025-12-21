// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import "./SharedTestSetup.sol";

contract TestRewardPool is SharedTestSetup {
    address public rewardPoolClone;

    IRewardPoolV1 REWARD_POOL;

    address public transferrer1;
    address public transferrer2;
    address public transferrer3;

    address public admin1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public admin2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address public admin3 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    function setUp() public {
        super.configure();

        vm.label(address(this), "TestRewardPool");

        vm.prank(mockOwner);
        rewardPoolClone = REWARD_POOL_REGISTRY.createRewardPool(
            "test reward pool",
            IRewardPoolV1.RedeemMethod.CustomERC1155,
            address(0),
            1,
            mockOwner,
            new address [](0),
            "",
            "",
            ""
        );

        REWARD_POOL = IRewardPoolV1(rewardPoolClone);

        transferrer1 = address(0x1);
        transferrer2 = address(0x2);
        transferrer3 = address(0x3);
    }

    function testCreateAssetPool() public {
        vm.startPrank(mockOwner);

        address assetPool = REWARD_POOL.createAssetPool(
            1
        );
        assert(assetPool != address(0));

        assertEq(IAssetPoolV1(assetPool).getRedeemTokenAmount(), 1);

        address [] memory pools = REWARD_POOL.getAssetPools();

        assertTrue(pools[1] == assetPool || pools[0] == assetPool);

        uint256 [] memory ids = REWARD_POOL.getAssetPoolIds();

        assertTrue(REWARD_POOL.getAssetPoolById(ids[0]) == assetPool || REWARD_POOL.getAssetPoolById(ids[1]) == assetPool);

        uint256 currentLength = REWARD_POOL.getAssetPools().length;
        uint256 amountOfPools = 5;

        for (uint i = 0; i < amountOfPools; ++i) {
            REWARD_POOL.createAssetPool(
                1
            );
        }

        assertEq(REWARD_POOL.getAssetPools().length, amountOfPools + currentLength);

        vm.stopPrank();
    }

    function testAddAdmins() public {
        address [] memory admins = new address [](3);

        admins[0] = admin1;
        admins[1] = admin2;
        admins[2] = admin3;

        bytes memory error_only_owner_allowed = bytes("RewardPoolV1: only owner allowed");

        vm.expectRevert(error_only_owner_allowed);
        REWARD_POOL.addAdmins(admins);

        vm.expectRevert(error_only_owner_allowed);
        vm.prank(admins[0]);
        REWARD_POOL.addAdmins(admins);

        vm.startPrank(mockOwner);
        REWARD_POOL.addAdmins(admins);

        address [] memory admins_ = REWARD_POOL.getAdmins();

        assertEq(admins_.length, admins.length);
        assertEq(admins[0], admin1);
        assertEq(admins[1], admin2);
        assertEq(admins[2], admin3);
    }

    function testRemoveAdmins() public {
        address [] memory admins = new address [](3);

        admins[0] = admin1;
        admins[1] = admin2;
        admins[2] = admin3;

        bytes memory error_only_owner_allowed = bytes("RewardPoolV1: only owner allowed");

        vm.expectRevert(error_only_owner_allowed);
        REWARD_POOL.addAdmins(admins);

        vm.expectRevert(error_only_owner_allowed);
        vm.prank(admins[0]);
        REWARD_POOL.addAdmins(admins);

        vm.startPrank(mockOwner);
        REWARD_POOL.addAdmins(admins);

        address [] memory removeAdmins = new address [](1);
        removeAdmins[0] = admin2;

        REWARD_POOL.removeAdmins(removeAdmins);

        assertEq(REWARD_POOL.getAdmins().length, admins.length - 1);
        assertFalse(_existsInArr(REWARD_POOL.getAdmins(), admin2));
    }

    function testSetActive() public {
        vm.startPrank(mockOwner);
        bool activeStatus = true;
        REWARD_POOL.setActive(activeStatus);
        assertEq(REWARD_POOL.isActive(), activeStatus);
        vm.stopPrank();
    }

    function testAddTransferrers() public {
        address[] memory transferrers = new address[](3);
        transferrers[0] = transferrer1;
        transferrers[1] = transferrer2;
        transferrers[2] = transferrer3;

        vm.startPrank(mockOwner);
        REWARD_POOL.addTransferrers(transferrers);

        address[] memory transferrers_ = REWARD_POOL.getTransferrers();

        assertEq(transferrers_.length, transferrers.length);
        assertEq(transferrers[0], transferrer1);
        assertEq(transferrers[1], transferrer2);
        assertEq(transferrers[2], transferrer3);

        vm.stopPrank();
    }

    function testRemoveTransferrers() public {
        address[] memory transferrers = new address[](3);
        transferrers[0] = transferrer1;
        transferrers[1] = transferrer2;
        transferrers[2] = transferrer3;

        vm.startPrank(mockOwner);
        REWARD_POOL.addTransferrers(transferrers);

        address[] memory removeTransferrers = new address[](1);
        removeTransferrers[0] = transferrer2;

        REWARD_POOL.removeTransferrers(removeTransferrers);

        assertEq(REWARD_POOL.getTransferrers().length, transferrers.length - 1);
        assertFalse(_existsInArr(REWARD_POOL.getTransferrers(), transferrer2));

        vm.stopPrank();
    }

    function _existsInArr(address [] memory arr, address addr) private pure returns (bool) {
        for (uint i = 0; i < arr.length; ++i) {
            if (arr[i] == addr) {
                return true;
            }
        }

        return false;
    }
}
