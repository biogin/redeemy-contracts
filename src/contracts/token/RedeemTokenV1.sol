// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@redeemy/interfaces/IRewardPoolV1.sol";

contract RedeemTokenV1 {
    IRewardPoolV1 REWARD_POOL;

    address public immutable rewardPool;

    mapping(address => bool) _blacklisted;

    modifier onlyOwner() {
        require(msg.sender == REWARD_POOL.getOwner(), "RedeemTokenV1: only owner allowed");
        _;
    }

    modifier onlyAdmin() {
        require(REWARD_POOL.isAdmin(msg.sender), "RedeemTokenV1: only admin allowed");
        _;
    }

    modifier onlyAssetPool() {
        require(REWARD_POOL.containsAssetPool(msg.sender), "RedeemTokenV1: only asset pool allowed");
        _;
    }

    constructor(address _rewardPool) {
        rewardPool = _rewardPool;

        REWARD_POOL = IRewardPoolV1(rewardPool);
    }

    function getBlacklisted(address _user) external view returns (bool) {
        return _blacklisted[_user];
    }

    function setBlacklisted(address _user, bool blacklisted_) external onlyOwner {
        _blacklisted[_user] = blacklisted_;
    }
}
