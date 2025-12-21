#!/bin/bash

if [ ! -d "abi/" ]
then
  mkdir abi/
fi

forge inspect --via-ir RewardPoolRegistryV1 abi > abi/RewardPoolRegistryV1.json
forge inspect --via-ir RewardPoolV1 abi > abi/RewardPoolV1.json
forge inspect --via-ir AssetPoolV1 abi > abi/AssetPoolV1.json
forge inspect --via-ir RewardVRFConsumerV1 abi > abi/RewardVRFConsumerV1.json

echo "Done"
