// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import "@redeemy/contracts/factory/RewardPoolFactoryV1.sol";
import "@redeemy/contracts/factory/AssetPoolFactoryV1.sol";

import "@redeemy/contracts/RewardPoolRegistryV1.sol";
import "@redeemy/contracts/RewardPoolV1.sol";
import "@redeemy/contracts/AssetPoolV1.sol";

contract DeployFactories is Script {
    function run() external {
        vm.startBroadcast(vm.envAddress("DEPLOYER_ADDRESS"));

        address forwarder = vm.envAddress("FORWARDER_ADDRESS");
        address vrfWrapper = vm.envAddress("VRF_WRAPPER_ADDRESS");
        address link = vm.envAddress("LINK_TOKEN_ADDRESS");

        address assetPool = address(new AssetPoolV1());

        address assetPoolFactory = address(new AssetPoolFactoryV1(assetPool));

        address rewardPool = address(new RewardPoolV1());

        address rewardPoolFactory = address(new RewardPoolFactoryV1(rewardPool, assetPoolFactory));

        RewardPoolRegistryV1 registry = new RewardPoolRegistryV1(
            rewardPoolFactory,
            forwarder,
            vrfWrapper,
            link,
            vm.envAddress("REVENUE_WALLET"),
            vm.envUint("REWARD_POOL_CREATION_FEE")
        );

        vm.stopBroadcast();
    }
}
