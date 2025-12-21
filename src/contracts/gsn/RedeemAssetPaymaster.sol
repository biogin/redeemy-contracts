// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@opengsn/contracts/src/BasePaymaster.sol";
import "@opengsn/contracts/src/forwarder/IForwarder.sol";

import "../../interfaces/IRewardPoolRegistryV1.sol";

contract RedeemAssetPaymaster is BasePaymaster {
    IRewardPoolRegistryV1 REWARD_POOL_REGISTRY;

    constructor(address _rewardPoolRegistry) {
        REWARD_POOL_REGISTRY = IRewardPoolRegistryV1(_rewardPoolRegistry);
    }

    function _preRelayedCall(
        GsnTypes.RelayRequest calldata relayRequest,
        bytes calldata signature,
        bytes calldata,
        uint256 maxPossibleGas
    )
    internal
    override
    virtual
    returns (bytes memory context, bool revertOnRecipientRevert) {
        (signature, maxPossibleGas);
        IForwarder.ForwardRequest calldata req = relayRequest.request;

        IAssetPoolV1 assetPool = IAssetPoolV1(req.to);

        IRewardPoolV1 rewardPool = IRewardPoolV1(assetPool.getRewardPool());

        require(REWARD_POOL_REGISTRY.getRewardPoolOwner(address(rewardPool)) != address(0));

        bytes4 method = GsnUtils.getMethodSig(req.data);

        require(method == IAssetPoolV1.redeemAsset.selector);

        uint256 amountOfAssetsToRedeem = abi.decode(req.data, (uint256));

        require(rewardPool.getRedeemTokenBalanceOf(req.from, req.to) >= amountOfAssetsToRedeem * assetPool.getRedeemTokenAmount());
        require(assetPool.getTotalNumberOfAssets() >= amountOfAssetsToRedeem);

        return ("", false);
    }

    function _postRelayedCall(
        bytes calldata context,
        bool success,
        uint256 gasUseWithoutPost,
        GsnTypes.RelayData calldata relayData
    )
    internal
    override
    virtual {
        (context, success, gasUseWithoutPost, relayData);
    }

    function versionPaymaster() external view override virtual returns (string memory){
        return "3.0.0-beta.3+opengsn.vpm.ipaymaster";
    }
}
