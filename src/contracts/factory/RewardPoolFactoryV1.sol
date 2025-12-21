// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";

import "@redeemy/interfaces/factory/IRewardPoolFactoryV1.sol";

contract RewardPoolFactoryV1 is IRewardPoolFactoryV1 {
    error InitializeCallFailed();

    address public immutable implementationContract;

    address public immutable assetPoolFactory;

    constructor(
        address _impl,
        address _assetPoolFactory
    ) {
        implementationContract = _impl;

        assetPoolFactory = _assetPoolFactory;
    }

    function create(
        address rewardPoolRegistry,

        address owner,

        string memory name,

        IRewardPoolV1.RedeemMethod redeemMethod,

        address redeemTokenContractAddress,
        uint256 redeemTokenAmount,

        address withdrawAddress,
        address [] memory admins,

        string memory tokenName,
        string memory tokenSymbol,
        string memory baseUri,

        address forwarder
    ) payable external returns (address, address, address) {
        address instance = Clones.clone(implementationContract);

        (bool success, bytes memory data) = instance.call{value : msg.value}(abi.encodeWithSignature("initialize(address,address,address,string,uint8,address,uint256,address,address[],string,string,string,address)",
            rewardPoolRegistry,

            assetPoolFactory,
            owner,

            name,

            redeemMethod,
            redeemTokenContractAddress,
            redeemTokenAmount,

            withdrawAddress,
            admins,

            tokenName,
            tokenSymbol,
            baseUri,

            forwarder
            )
        );

        (address redeemToken, address assetPool) = abi.decode(data, (address, address));

        if (!success) revert InitializeCallFailed();

        return (instance, redeemToken, assetPool);
    }
}
