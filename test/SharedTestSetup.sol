// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import "../src/interfaces/IRewardPoolRegistryV1.sol";

import "../src/contracts/factory/AssetPoolFactoryV1.sol";
import "../src/contracts/factory/RewardPoolFactoryV1.sol";

import "../src/contracts/RewardPoolRegistryV1.sol";
import "../src/contracts/RewardPoolV1.sol";
import "../src/contracts/AssetPoolV1.sol";

import "./mocks/chainlink/Link.sol";
import "./mocks/chainlink/VRFV2Wrapper.sol";

contract SharedTestSetup is Test {
    address internal mockOwner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 internal signerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    uint256 sharedNonce;

    AssetPoolFactoryV1 ASSET_POOL_FACTORY;

    RewardPoolFactoryV1 REWARD_POOL_FACTORY;

    RewardPoolRegistryV1 REWARD_POOL_REGISTRY;

    RewardPoolRegistryV1 REWARD_POOL_REGISTRY_WITH_FEE;
    address revenueWallet;

    address public linkToken;
    address public vrfV2Wrapper;

    function configure() internal {
        vm.startPrank(mockOwner);
        address assetPool = address(new AssetPoolV1());

        ASSET_POOL_FACTORY = new AssetPoolFactoryV1(assetPool);

        address rewardPool = address(new RewardPoolV1());

        REWARD_POOL_FACTORY = new RewardPoolFactoryV1(rewardPool, address(ASSET_POOL_FACTORY));

        linkToken = address(new LinkToken());

        vrfV2Wrapper = address(new VRFV2Wrapper());

        REWARD_POOL_REGISTRY = new RewardPoolRegistryV1(address(REWARD_POOL_FACTORY), address(0), vrfV2Wrapper, linkToken, mockOwner, 0);

        revenueWallet = getRandomAddress();

        REWARD_POOL_REGISTRY_WITH_FEE = new RewardPoolRegistryV1(address(REWARD_POOL_FACTORY), address(0), vrfV2Wrapper, linkToken, revenueWallet, 1 ether);

        vm.stopPrank();
    }

    function getRandomAddress() internal returns (address) {
        address randomAddress = address(uint160(uint(keccak256(abi.encodePacked(sharedNonce, blockhash(block.number))))));

        vm.deal(randomAddress, 10 ether);

        sharedNonce++;

        return randomAddress;
    }

    function getRandomWords() internal returns (uint256[] memory) {
        uint256 [] memory randomWords = new uint256[](5);

        randomWords[0] = getRandomNumber();
        randomWords[1] = getRandomNumber();
        randomWords[2] = getRandomNumber();
        randomWords[3] = getRandomNumber();
        randomWords[4] = getRandomNumber();

        return randomWords;
    }

    function getRandomNumber() internal returns (uint256) {
        return uint(keccak256(abi.encodePacked(sharedNonce++, blockhash(block.number))));
    }
}
