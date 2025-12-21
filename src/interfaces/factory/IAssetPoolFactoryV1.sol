// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IAssetPoolFactoryV1 {
    function create(
        address rewardPool,
        uint256 id,
        uint256 redeemTokenAmount
    ) payable external returns (address);
}
