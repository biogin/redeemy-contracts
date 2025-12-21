// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

import "@redeemy/interfaces/IRewardPoolV1.sol";

interface IAssetPoolV1 is IERC721Receiver, IERC1155Receiver {
    // =============================================================
    //                            ERRORS
    // =============================================================

    /*
     * Pool owner/admin should deposit at least one asset in the asset pool
     */
    error DepositAtLeastOneAsset();

    /*
     * The caller should redeem at least one asset in the asset pool
     */
    error RedeemAtLeastOneAsset();

    /*
     * Got invalid redeem method
     */
    error InvalidRedeemMethod();

    /*
     * Should deposit at least one asset in the asset pool
     */
    error RedeemMoreThanMaxAmount();

    /*
     * The caller is trying to redeem more assets than there is in the pool
     */
    error NotEnoughAssetsInThePool();

    /*
     * Insufficient token balance
     */
    error InsufficientBalance();

    /*
     * Insufficient approval balance
     */
    error InsufficientApproval();

    /*
     * Token transfer failed
     */
    error TransferFailed();

    // =============================================================
    //                            ENUMS
    // =============================================================

    enum AssetType {
        ERC721,
        ERC20,
        NativeToken
    }

    // =============================================================
    //                            STRUCTS
    // =============================================================

    struct AssetBox {
        address depositer;
        AssetType assetType;
        // Number of cards in the box
        uint256 numberOfCards;
        // ERC721 tokenId or ERC20 amount
        uint256 amountOrTokenId;
    }

    struct FungibleWithdrawInfo {
        uint256 totalToWithdraw;
        AssetBox boxToWithdraw;
        bool found;
        uint256 k;
    }

    struct NonFungibleWithdrawInfo {
        uint256 totalToWithdraw;
        uint256 tokenId;
        bool found;
        uint256 k;
    }

    // =============================================================
    //                            EVENTS
    // =============================================================

    /* @dev Emitted when `admin` or one of the admins deposits `amount` of assets in the pool */
    event AssetsDeposited(
        address indexed admin,
        address[] erc20ContractAddresses,
        AssetBox[][] erc20Boxes,
        address[] erc721ContractAddresses,
        uint256[][] erc721TokenIds,
        AssetBox[] nativeTokenBoxes,
        uint256 numberOfDepositedAssets
    );

    /* @dev Emitted when `admin` withdraws assets from the pool */
    event AssetsWithdrawn(
        address indexed admin,
        address[] erc20ContractAddresses,
        AssetBox[][] erc20Boxes,
        address[] erc721ContractAddresses,
        uint256[][] erc721TokenIds,
        AssetBox[] nativeTokenBoxes,
        uint256 numberOfWithdrawnAssets
    );

    event RedeemAssetsRequested(address receiver, uint256 [] requestIds);

    /* @dev Emitted when `receiver` redeems an asset using reward pool's redeem method */
    event AssetRedeemed(
        uint256 requestId,
        address indexed receiver,
        address indexed assetContract,
        AssetBox assetBox
    );

    /* @dev Emitted when `transferrer` transfers `amount` of redeem token to `to` */
    event RedeemTokenTransferred(
        address indexed transferrer,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    /* @dev Emitted when a new redeem token amount is changed to `newAmount` by `owner`  */
    event RedeemTokenAmountChanged(
        address indexed owner,
        uint256 newAmount
    );

    // =============================================================
    //                            IAssetPoolV1
    // =============================================================

    /* @dev Returns the id of the asset pool */
    function id() external view returns (uint256);

    /* @dev Returns the reward pool address this pool belongs to */
    function getRewardPool() external view returns (address);

    /*
     * @dev Returns the amount of units required to transfer/burn when calling redeemAsset()
     */
    function getRedeemTokenAmount() external view returns (uint256);

    /*
     * @dev Returns all the contracts by `assetType`
     */
    function getContractsByAssetType(AssetType assetType) external view returns (address [] memory);

    /*
     * @dev Returns all the ERC721 assets present in this asset pool for `contractAddress`
     */
    function getERC721Assets(address contractAddress) external view returns (AssetBox[] memory);

    /*
     * @dev Returns all the ERC20 assets present in this asset pool for `contractAddress`
     */
    function getERC20Assets(address contractAddress) external view returns (AssetBox[] memory);

    /*
     * @dev Returns all the native token assets present in this asset pool
     */
    function getNativeTokenAssets() external view returns (AssetBox[] memory);

    /*
     * @dev Returns all the deposited asset types in the pool
     */
    function getDepositedAssetTypes() external view returns (AssetType [] memory);

    /*
     * @dev Returns the amount of assets deposited in the pool
     */
    function getTotalNumberOfAssets() external view returns (uint256);

    /* @dev Deposits assets in the asset pool */
    function depositAssets(
        address [] calldata erc20ContractAddresses,
        AssetBox [][] calldata erc20Boxes,

        address [] calldata erc721ContractAddresses,
        uint256 [][] calldata erc721TokenIds,

        AssetBox [] calldata nativeTokenBoxes
    ) payable external;

    /* @dev Withdraw assets in the asset pool */
    function withdrawAssets(
        address [] calldata erc20ContractAddresses,
        AssetBox [][] calldata erc20Boxes,

        address [] calldata erc721ContractAddresses,
        uint256 [][] calldata erc721TokenIds,

        AssetBox [] calldata nativeTokenBoxes
    ) external;

    /* @dev Transfers `number` of redeem tokens to `to` */
    function transferRedeemTokenNumber(address to, uint256 number) external;

    /* @dev Transfers `amount` of redeem token to `to` */
    function transferRedeemTokenAmount(address to, uint256 amount) external;

    /*
     * @dev Redeems asset for the caller and depending on the redeemMethod
     * burns/takes redeem token and sends a request to chainlink for randomization
     */
    function redeemAsset(uint256 amount) external;

    /*
     * @notice Randomizes asset for the `receiver`
     * @dev Called by ChainLink VRF consumer
     */
    function fulfillRedeemAsset(
        uint256 requestId,
        address receiver,
        uint256[] memory
    ) external returns (AssetType, address, uint256);

    /*
     * @dev Sets the new redeem token amount
     */
    function setRedeemTokenAmount(uint256 redeemAmount) external;
}

