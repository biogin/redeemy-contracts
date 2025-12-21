// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IRewardVRFConsumerV1
{
    function requestRandomWords(address assetPool, address assetReceiver) external returns (uint256);
}
