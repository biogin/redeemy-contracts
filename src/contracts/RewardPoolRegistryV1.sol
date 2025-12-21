// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/console2.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "@redeemy/interfaces/IRewardPoolRegistryV1.sol";
import "@redeemy/interfaces/factory/IRewardPoolFactoryV1.sol";

import "@redeemy/contracts/RewardPoolV1.sol";
import "@redeemy/contracts/RewardVRFConsumerV1.sol";
import "@redeemy/contracts/gsn/RedeemAssetPaymaster.sol";
import "@redeemy/contracts/utils/StringUtils.sol";

contract RewardPoolRegistryV1 is IRewardPoolRegistryV1, Ownable {
    uint256 public constant MAX_NAME_LENGTH = 50;

    address public immutable rewardPoolFactory;
    address public immutable vrfWrapper;
    address public immutable link;
    address public immutable trustedForwarder;

    address public revenueWallet;

    uint256 private _rewardPoolCreationFee;

    mapping(string => address) private _usedRewardPoolNames;

    mapping(address => address) private _ownerToVRFConsumer;

    mapping(address => address) private _ownerToPaymaster;

    mapping(address => address[]) private _ownerToRewardPools;
    mapping(address => address) private _rewardPoolToOwner;

    modifier onlyPoolOwner(address rewardPool) {
        require(_rewardPoolToOwner[rewardPool] == msg.sender);
        _;
    }

    constructor(
        address _rewardPoolFactory,
        address _forwarder,
        address _vrfWrapper,
        address _link,
        address _revenueWallet,
        uint256 rewardPoolCreationFee
    ) {
        rewardPoolFactory = _rewardPoolFactory;
        vrfWrapper = _vrfWrapper;
        link = _link;
        trustedForwarder = _forwarder;
        revenueWallet = _revenueWallet;
        _rewardPoolCreationFee = rewardPoolCreationFee;
    }

    /// @inheritdoc IRewardPoolRegistryV1
    function getVRFConsumer(address owner) external view returns (address) {
        return _ownerToVRFConsumer[owner];
    }

    /// @inheritdoc IRewardPoolRegistryV1
    function getPaymaster(address owner) external view returns (address) {
        return _ownerToPaymaster[owner];
    }

    /// @inheritdoc IRewardPoolRegistryV1
    function getRewardPoolsByAddress(address owner) external view returns (address[] memory) {
        return _ownerToRewardPools[owner];
    }

    /// @inheritdoc IRewardPoolRegistryV1
    function getRewardPoolOwner(address pool) external view returns (address) {
        return _rewardPoolToOwner[pool];
    }

    /// @inheritdoc IRewardPoolRegistryV1
    function getRewardPoolCreationFee() external view returns (uint256) {
        return _rewardPoolCreationFee;
    }

    function rewardPoolNameExists(string memory rewardPoolName) external view returns (bool) {
        return _rewardPoolNameExists(rewardPoolName);
    }

    /// @inheritdoc IRewardPoolRegistryV1
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
    ) external payable returns (address) {
        name = _validateName(name);

        _transferCreationFee();

        address owner = msg.sender;

        address vrfConsumer = _setVRFConsumer(owner);

        if (withdrawAddress == address(0)) {
            withdrawAddress = owner;
        }

        (
        address rewardPool,
        address redeemToken,
        address assetPool
        ) = IRewardPoolFactoryV1(rewardPoolFactory).create(
            address(this),
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
            trustedForwarder
        );

        _ownerToRewardPools[owner].push(rewardPool);

        _rewardPoolToOwner[rewardPool] = owner;

        _usedRewardPoolNames[name] = rewardPool;

        emit RewardPoolCreated(
            owner,
            rewardPool,
            name,
            redeemMethod,
            redeemToken,
            redeemTokenAmount,
            tokenName,
            tokenSymbol,
            baseUri,
            withdrawAddress,
            admins,
            assetPool,
            vrfConsumer
        );

        return rewardPool;
    }


    function setRewardPoolCreationFee(uint256 _newRewardPoolCreationFee) external onlyOwner {
        _rewardPoolCreationFee = _newRewardPoolCreationFee;
    }

    function setRevenueWallet(address _newRevenueWallet) external onlyOwner {
        revenueWallet = _newRevenueWallet;
    }

    function setNewRewardPoolName(address pool, string memory rewardPoolName) external onlyPoolOwner(pool) {
        rewardPoolName = _validateName(rewardPoolName);

        _usedRewardPoolNames[rewardPoolName] = pool;

        IRewardPoolV1(pool).setNewName(rewardPoolName);
    }

    function createPaymaster() public {
        address owner = msg.sender;

        if (_ownerToPaymaster[owner] == address(0)) {
            address paymaster = _createAndSetPaymaster(owner);

            emit PaymasterCreated(owner, paymaster);
        }
    }

    function _createAndSetPaymaster(address owner) private returns (address paymaster) {
        paymaster = address(
            new RedeemAssetPaymaster(address(this))
        );

        _ownerToPaymaster[owner] = paymaster;

        return paymaster;
    }

    function _setVRFConsumer(address owner) private returns (address) {
        address vrfConsumer = _ownerToVRFConsumer[owner];

        if (vrfConsumer == address(0)) {
            vrfConsumer = _createAndSetVRFConsumer(
                owner,
                vrfWrapper,
                link
            );

            emit VRFConsumerCreated(owner, vrfConsumer);
        }

        return vrfConsumer;
    }

    function _createAndSetVRFConsumer(
        address owner,
        address _vrfWrapper,
        address _link
    ) private returns (address vrfConsumer) {
        vrfConsumer = address(
            new RewardVRFConsumerV1(
                address(this),
                owner,
                _vrfWrapper,
                _link
            )
        );

        _ownerToVRFConsumer[owner] = vrfConsumer;

        return vrfConsumer;
    }

    function _validateName(string memory name) private returns (string memory) {
        string memory standardizedCaseName = StringUtils.trim(name);

        if (bytes(standardizedCaseName).length == 0 || bytes(standardizedCaseName).length > MAX_NAME_LENGTH) {
            revert InvalidName();
        }

        if (_rewardPoolNameExists(standardizedCaseName)) {
            revert NameAlreadyExists();
        }

        return standardizedCaseName;
    }

    function _transferCreationFee() private {
        if (_rewardPoolCreationFee > 0) {
            uint256 val = msg.value;

            if (val != _rewardPoolCreationFee) {
                revert InvalidFeeAmountSent();
            }

            (bool success,) = revenueWallet.call{value : val}("");

            require(success, "transfer failed");
        }
    }

    function _rewardPoolNameExists(string memory rewardPoolName) private view returns (bool) {
        return _usedRewardPoolNames[rewardPoolName] != address(0);
    }
}
