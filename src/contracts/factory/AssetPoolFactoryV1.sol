// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@redeemy/interfaces/factory/IAssetPoolFactoryV1.sol";

contract AssetPoolFactoryV1 is IAssetPoolFactoryV1 {
    error InitializeCallFailed();

    address public immutable implementationContract;

    constructor(
        address _impl
    ) {
        implementationContract = _impl;
    }

    function create(
        address rewardPool,
        uint256 id,
        uint256 redeemTokenAmount
    ) payable external returns (address instance) {
        instance = Clones.clone(implementationContract);

        (bool success,) = instance.call{value : msg.value}(abi.encodeWithSignature("initialize(address,uint256,uint256)",
            rewardPool,
            id,
            redeemTokenAmount
            )
        );

        if (!success) revert InitializeCallFailed();
    }
}
