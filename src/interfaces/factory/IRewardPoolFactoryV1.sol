// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../IRewardPoolV1.sol";

interface IRewardPoolFactoryV1 {
    /*
     * @dev Creates a new instance of the RewardPool
     */
    function create(
        address rewardPoolRegistry,

        address owner,

        string memory name,

        IRewardPoolV1.RedeemMethod redeemMethod,

        address redeemTokenContractAddress,
        uint256 redeemTokenAmount,

        address withdrawAddress,
        address [] memory admins,

    /* only if redeemMethod is Custom* and `owner` wants to create a new token */
        string memory tokenName,
        string memory tokenSymbol,
    /**/
        string memory baseUri,

        address forwarder
    ) payable external returns (address rewardPool, address redeemToken, address assetPool);
}
