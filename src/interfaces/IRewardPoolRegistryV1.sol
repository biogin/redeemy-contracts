// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@redeemy/interfaces/IRewardPoolV1.sol";

interface IRewardPoolRegistryV1 {
    // =============================================================
    //                            ERRORS
    // =============================================================

    error InvalidName();

    error NameAlreadyExists();

    error InvalidFeeAmountSent();

    // =============================================================
    //                            EVENTS
    // =============================================================

    /* @dev Emitted when a new `rewardPool` is created by the `owner` */
    event RewardPoolCreated(
        address indexed owner,
        address rewardPool,
        string rewardPoolName,
        IRewardPoolV1.RedeemMethod redeemMethod,
        address redeemTokenContractAddress,
        uint256 redeemTokenAmount,
        string name,
        string symbol,
        string baseUri,
        address withdrawAddress,
        address [] admins,
        address assetPool,
        address vrfConsumer
    );

    /* @dev Emitted when `vrfConsumer` is created by the `owner` */
    event VRFConsumerCreated(address indexed owner, address vrfConsumer);

    /* @dev Emitted when new `paymaster` is created by the `owner` */
    event PaymasterCreated(address indexed owner, address paymaster);

    // =============================================================
    //                       IRewardPoolRegistryV1
    // =============================================================

    /* @dev Returns the vrf consumer deployed by `owner` */
    function getVRFConsumer(address owner) external view returns (address);

    /* @dev Returns the paymaster deployed by `owner` */
    function getPaymaster(address owner) external view returns (address);

    /* @dev Returns all the reward pools created by the `owner` */
    function getRewardPoolsByAddress(address owner) external view returns (address [] memory);

    /* @dev Returns owner of the `pool` */
    function getRewardPoolOwner(address pool) external view returns (address);

    /* @dev Returns the required fee amount for reward pool creation */
    function getRewardPoolCreationFee() external view returns (uint256);

    /* @dev Creates a new reward pool */
    function createRewardPool(
        string memory name,
        IRewardPoolV1.RedeemMethod redeemMethod,
        address redeemTokenContractAddress,
        uint256 redeemTokenAmount,
        address withdrawAddress,
        address [] memory admins,
        string memory tokenName,
        string memory tokenSymbol,
        string memory baseUri
    ) external payable returns (address);
}
