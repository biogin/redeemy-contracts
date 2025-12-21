// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@chainlink/v0.8/VRFV2WrapperConsumerBase.sol";

import "@redeemy/interfaces/IRewardVRFConsumerV1.sol";
import "@redeemy/interfaces/IAssetPoolV1.sol";
import "@redeemy/interfaces/IRewardPoolRegistryV1.sol";

contract RewardVRFConsumerV1 is IRewardVRFConsumerV1, VRFV2WrapperConsumerBase {
    struct Request {
        address assetPool;
        address receiver;
    }

    uint32 callbackGasLimit = 400000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 10;

    address public immutable linkAddress;

    address public immutable rewardPoolRegistry;

    address public immutable owner;

    mapping(uint256 => Request) public requestIds;

    modifier onlyRewardPool() {
        require(IRewardPoolRegistryV1(rewardPoolRegistry).getRewardPoolOwner(msg.sender) == owner, "RedeemVRFConsumerV1: only reward pool allowed");
        _;
    }

    constructor(
        address _rewardPoolRegistry,
        address _owner,
        address _wrapper,
        address _link
    )
    VRFV2WrapperConsumerBase(_link, _wrapper)
    {
        linkAddress = _link;
        rewardPoolRegistry = _rewardPoolRegistry;
        owner = _owner;
    }

    function requestRandomWords(address assetPool, address receiver)
    external
    onlyRewardPool
    returns (uint256 requestId)
    {
        requestId = requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numWords
        );
        requestIds[requestId] = Request({
        assetPool : assetPool,
        receiver : receiver
        });

        return requestId;
    }

    function depositLink(uint256 amount) public {
        LinkTokenInterface link = LinkTokenInterface(linkAddress);
        require(
            link.transferFrom(msg.sender, address(this), amount),
            "Failed to transfer"
        );
    }

    function withdrawLink() public {
        require(msg.sender == owner, "RedeemVRFConsumerV1: only owner can withdraw link");

        LinkTokenInterface link = LinkTokenInterface(linkAddress);
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        Request storage req = requestIds[requestId];

        IAssetPoolV1(req.assetPool).fulfillRedeemAsset(requestId, req.receiver, randomWords);
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (Request memory)
    {
        return requestIds[_requestId];
    }
}
