// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@redeemy/interfaces/IAssetPoolV1.sol";

interface IRewardPoolV1 {
    // =============================================================
    //                            ENUMS
    // =============================================================

    enum RedeemMethod {
        ExistingERC20,
        CustomERC20,
        CustomERC1155
    }

    // =============================================================
    //                            EVENTS
    // =============================================================

    /* @dev Emitted when a new `assetPool` is created by the `creator` */
    event AssetPoolCreated(
        address indexed creator,
        uint256 id,
        address assetPool,
        uint256 redeemTokenAmount
    );

    /* @dev Emitted when new `admins` are added to the reward pool */
    event AdminsAdded(address[] admins);

    /* @dev Emitted when `admins` are removed from the reward pool */
    event AdminsRemoved(address[] admins);

    /* @dev Emitted when new `transferrers` are added to the reward pool */
    event TransferrersAdded(address[] transferrers);

    /* @dev Emitted when `transferrers` are removed from the reward pool */
    event TransferrersRemoved(address[] transferrers);

    /* @dev Emitted when withdrawAddress is changed */
    event WithdrawAddressChanged(address newWithdrawAddress);

    /* @dev Emitted when the status is changed */
    event ActiveStatusChanged(bool active);

    /* @dev Emitted when the name is changed to `newName` */
    event NameChanged(string newName);

    // =============================================================
    //                            IRewardPoolV1
    // =============================================================

    /* @dev Returns the name of the reward pool */
    function name() external view returns (string memory);

    /* @dev Returns whether the reward pool is active */
    function isActive() external view returns (bool);

    /* @dev Returns the owner of the pool */
    function getOwner() external view returns (address);

    /* @dev Returns the withdraw address */
    function getWithdrawAddress() external view returns (address);

    /* @dev Returns all the admins of the reward pool */
    function getAdmins() external view returns (address [] memory);

    /* @dev Returns whether `addr` is admin or not */
    function isAdmin(address addr) external view returns (bool);

    /* @dev Returns all the transferrers of the reward pool */
    function getTransferrers() external view returns (address [] memory);

    /* @dev Returns whether `addr` is allowed to transfer redeem token from the pool */
    function isTransferrer(address addr) external view returns (bool);

    /* @dev Returns all the asset pools created in the reward pool */
    function getAssetPools() external view returns (address [] memory);

    /* @dev Returns all the asset pool ids  */
    function getAssetPoolIds() external view returns (uint256 [] memory);

    /* @dev Returns asset pool by `id`  */
    function getAssetPoolById(uint256 id) external view returns (address);

    /* @dev Returns true if this reward pool has `assetPool`; false otherwise */
    function containsAssetPool(address assetPool) external view returns (bool);

    /* @dev Returns the total amount of rewards across all the asset pools */
    function getTotalNumberOfRewards() external view returns (uint256);

    /* @dev Returns the redeem method set by the asset pool creator */
    function getRedeemMethod() external view returns (RedeemMethod);

    /* @dev Returns the contract address of the redeem token */
    function getRedeemTokenContractAddress() external view returns (address);

    /* @dev Returns `addr`s redeem token balance for `assetPool` */
    function getRedeemTokenBalanceOf(address addr, address assetPool) external view returns (uint256);

    /* @dev Returns the VRF consumer address */
    function getVRFConsumer() external view returns (address);

    /* @dev Returns trusted forwarder for GSN redeemAsset() */
    function getTrustedForwarder() external view returns (address);

    /* @dev Returns maximum number of rewards allowed per tx */
    function getMaxNumberOfRewardsPerTx() external view returns (uint256);

    /* @dev Creates a new asset pool */
    function createAssetPool(
        uint256 redeemTokenAmount
    ) external returns (address);

    /* @dev Sets reward pool's `active` status */
    function setActive(bool active) external;

    /* @dev Sets a new `name` for the reward pool */
    function setNewName(string memory name) external;

    /* @dev Adds `admins` to the reward pool */
    function addAdmins(address [] memory admins) external;

    /* @dev Removes `admins` from the reward pool */
    function removeAdmins(address [] memory admins) external;

    /* @dev Adds `transferrers` to the reward pool */
    function addTransferrers(address [] memory transferrers) external;

    /* @dev Removes `transferrers` from the reward pool */
    function removeTransferrers(address [] memory transferrers) external;

    /* @dev Request random words from ChainLinkVRFConsumer on behalf of `assetPool` for the `receiver` */
    function requestRandomWords(address receiver) external returns (uint256);
}

