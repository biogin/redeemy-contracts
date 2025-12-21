// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "@redeemy/interfaces/IRewardPoolRegistryV1.sol";
import "@redeemy/interfaces/IRewardVRFConsumerV1.sol";
import "@redeemy/interfaces/factory/IAssetPoolFactoryV1.sol";

import "@redeemy/contracts/token/ERC1155RedeemTokenV1.sol";
import "@redeemy/contracts/token/ERC20RedeemTokenV1.sol";

contract RewardPoolV1 is IRewardPoolV1, Initializable, ERC165 {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Counters for Counters.Counter;

    uint256 public constant MAX_NUMBER_OF_REWARDS_PER_TX = 10;
    uint256 public constant MAX_NUMBER_OF_ASSET_POOL = 10;
    uint256 public constant MAX_ADMINS = 10;
    uint256 public constant MAX_TRANSFERRERS = 3;

    address public rewardPoolRegistry;
    address public assetPoolFactory;

    string private _name;
    address private _owner;
    address private _withdrawAddress;
    address private _redeemTokenContractAddress;
    address private _forwarder;
    bool private _active;

    IRewardPoolV1.RedeemMethod private _redeemMethod;

    Counters.Counter private _assetPoolId;
    /*
         TODO
         Bits Layout:
       - // - [0..159]   `assetPoolAddress`
       - // - [160..256] `assetPoolId`
         EnumerableSet.UintSet private _assetPoolsPacked;
    */
    mapping(uint256 => address) private _assetPoolIdToAssetPool;

    EnumerableSet.AddressSet private _admins;
    EnumerableSet.AddressSet private _transferrers;
    EnumerableSet.AddressSet private _assetPools;
    EnumerableSet.UintSet private _assetPoolIds;

    modifier onlyRegistry() {
        require(msg.sender == rewardPoolRegistry, "RewardPoolV1: only registry allowed");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "RewardPoolV1: only owner allowed");
        _;
    }

    modifier onlyAdmin() {
        address sender = msg.sender;
        require(_admins.contains(sender) || sender == _owner, "RewardPoolV1: only admin allowed");
        _;
    }

    modifier onlyAssetPool() {
        require(_assetPools.contains(msg.sender), "RewardPoolV1: only asset pool allowed");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _rewardPoolRegistry,

        address _assetPoolFactory,

        address owner_,
        string memory name_,

        IRewardPoolV1.RedeemMethod redeemMethod_,

        address redeemTokenContractAddress_,
        uint256 _redeemTokenAmount,

        address withdrawAddress_,
        address [] memory admins_,

        string memory _tokenName,
        string memory _tokenSymbol,

        string memory _baseUri,

        address forwarder_
    ) public payable initializer returns (address redeemToken, address assetPool) {
        rewardPoolRegistry = _rewardPoolRegistry;

        assetPoolFactory = _assetPoolFactory;

        _name = name_;

        _owner = owner_;
        _redeemMethod = redeemMethod_;
        _withdrawAddress = withdrawAddress_;
        _forwarder = forwarder_;
        _active = true;

        redeemToken = _setOrCreateRedeemToken(
            redeemMethod_,
            redeemTokenContractAddress_,
            _tokenName,
            _tokenSymbol,
            _baseUri
        );

        // start from 1
        _assetPoolId.increment();

        _addAdmins(admins_);

        assetPool = _createAssetPool(_redeemTokenAmount);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IRewardPoolV1).interfaceId ||
        super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IRewardPoolV1
    function name() external view returns (string memory) {
        return _name;
    }

    /// @inheritdoc IRewardPoolV1
    function isActive() external view returns (bool) {
        return _active;
    }

    /// @inheritdoc IRewardPoolV1
    function getOwner() external view returns (address) {
        return _owner;
    }

    /// @inheritdoc IRewardPoolV1
    function getWithdrawAddress() external view returns (address) {
        return _withdrawAddress;
    }

    /// @inheritdoc IRewardPoolV1
    function getAdmins() external view returns (address [] memory) {
        return _admins.values();
    }

    /// @inheritdoc IRewardPoolV1
    function getTransferrers() external view returns (address [] memory) {
        return _transferrers.values();
    }

    /// @inheritdoc IRewardPoolV1
    function getAssetPools() external view returns (address [] memory) {
        return _assetPools.values();
    }

    /// @inheritdoc IRewardPoolV1
    function getAssetPoolById(uint256 id) external view returns (address) {
        return _assetPoolIdToAssetPool[id];
    }

    /// @inheritdoc IRewardPoolV1
    function getAssetPoolIds() external view returns (uint256 [] memory) {
        return _assetPoolIds.values();
    }

    /// @inheritdoc IRewardPoolV1
    function containsAssetPool(address assetPool) external view returns (bool) {
        return _assetPools.contains(assetPool);
    }

    /// @inheritdoc IRewardPoolV1
    function getTotalNumberOfRewards() external view returns (uint256) {
        uint256 total = 0;
        // should be okay since the number of asset pools won't be that high
        address[] memory pools = _assetPools.values();
        uint256 len = pools.length;

        for (uint i = 0; i < len; ++i) {
            total += IAssetPoolV1(pools[i]).getTotalNumberOfAssets();
        }

        return total;
    }

    /// @inheritdoc IRewardPoolV1
    function isAdmin(address addr) external view returns (bool) {
        return _admins.contains(addr) || addr == _owner;
    }

    /// @inheritdoc IRewardPoolV1
    function isTransferrer(address addr) external view returns (bool) {
        return _transferrers.contains(addr) || addr == _owner;
    }

    /// @inheritdoc IRewardPoolV1
    function getRedeemMethod() external view returns (RedeemMethod) {
        return _redeemMethod;
    }

    /// @inheritdoc IRewardPoolV1
    function getRedeemTokenContractAddress() external view returns (address) {
        return _redeemTokenContractAddress;
    }

    /// @inheritdoc IRewardPoolV1
    function getRedeemTokenBalanceOf(address addr, address assetPool) external view returns (uint256 balance) {
        IAssetPoolV1 ap = IAssetPoolV1(assetPool);

        if (_redeemMethod == RedeemMethod.CustomERC1155) {
            balance = IERC1155(_redeemTokenContractAddress).balanceOf(addr, ap.id());
        } else {
            balance = IERC20(_redeemTokenContractAddress).balanceOf(addr) / ap.getRedeemTokenAmount();
        }

        return balance;
    }

    /// @inheritdoc IRewardPoolV1
    function getMaxNumberOfRewardsPerTx() external pure returns (uint256) {
        return MAX_NUMBER_OF_REWARDS_PER_TX;
    }

    /// @inheritdoc IRewardPoolV1
    function getVRFConsumer() external view returns (address) {
        return IRewardPoolRegistryV1(rewardPoolRegistry).getVRFConsumer(_owner);
    }

    /// @inheritdoc IRewardPoolV1
    function getTrustedForwarder() external view returns (address) {
        return _forwarder;
    }

    /// @inheritdoc IRewardPoolV1
    function createAssetPool(
        uint256 _redeemTokenAmount
    ) external onlyOwner returns (address) {
        return _createAssetPool(_redeemTokenAmount);
    }

    function setWithdrawAddress(address _newWithdrawAddress) external onlyOwner {
        _withdrawAddress = _newWithdrawAddress;

        emit WithdrawAddressChanged(_newWithdrawAddress);
    }

    /// @inheritdoc IRewardPoolV1
    function setActive(bool active_) external onlyOwner {
        _active = active_;

        emit ActiveStatusChanged(active_);
    }

    /// @inheritdoc IRewardPoolV1
    function setNewName(string memory name_) external onlyRegistry {
        _name = name_;

        emit NameChanged(name_);
    }

    /// @inheritdoc IRewardPoolV1
    function addTransferrers(address [] memory transferrers) external onlyOwner {
        require(transferrers.length + _transferrers.length() <= MAX_TRANSFERRERS, "RewardPoolV1: cant add that many transferrers");

        for (uint i = 0; i < transferrers.length; i++) {
            _transferrers.add(transferrers[i]);
        }

        emit TransferrersAdded(transferrers);
    }

    /// @inheritdoc IRewardPoolV1
    function removeTransferrers(address [] memory transferrers) external onlyOwner {
        for (uint i = 0; i < transferrers.length; i++) {
            _transferrers.remove(transferrers[i]);
        }

        emit TransferrersRemoved(transferrers);
    }

    /// @inheritdoc IRewardPoolV1
    function addAdmins(address [] memory admins) external onlyOwner {
        _addAdmins(admins);

        emit AdminsAdded(admins);
    }

    /// @inheritdoc IRewardPoolV1
    function removeAdmins(address [] memory admins) external onlyOwner {
        for (uint i = 0; i < admins.length; i++) {
            _admins.remove(admins[i]);
        }

        emit AdminsRemoved(admins);
    }

    /// @inheritdoc IRewardPoolV1
    function requestRandomWords(address receiver) external onlyAssetPool returns (uint256) {
        address vrfConsumer = IRewardPoolRegistryV1(rewardPoolRegistry).getVRFConsumer(_owner);

        return IRewardVRFConsumerV1(vrfConsumer).requestRandomWords(msg.sender, receiver);
    }

    function _setOrCreateRedeemToken(
        RedeemMethod redeemMethod,
        address redeemTokenContractAddress,
        string memory name_,
        string memory symbol_,
        string memory baseUri
    ) private returns (address) {
        if (redeemMethod == RedeemMethod.ExistingERC20) {
            require(redeemTokenContractAddress != address(0), "RewardPoolV1: address cannot be zero");

            _redeemTokenContractAddress = redeemTokenContractAddress;
        } else if (redeemMethod == RedeemMethod.CustomERC20) {
            _redeemTokenContractAddress = address(
                new ERC20RedeemTokenV1(
                    address(this),
                    name_,
                    symbol_
                )
            );
        } else if (redeemMethod == RedeemMethod.CustomERC1155) {
            _redeemTokenContractAddress = address(
                new ERC1155RedeemTokenV1(
                    address(this),
                    baseUri
                )
            );
        } else {
            revert("RewardPoolV1: unknown redeem method");
        }

        return _redeemTokenContractAddress;
    }

    function _addAdmins(address [] memory admins) private {
        require(admins.length + _admins.length() <= MAX_ADMINS, "RewardPoolV1: cant add that many admins");

        for (uint i = 0; i < admins.length; i++) {
            _admins.add(admins[i]);
        }
    }

    function _createAssetPool(
        uint256 _redeemTokenAmount
    ) private returns (address assetPool) {
        uint256 id = _assetPoolId.current();

        assetPool = IAssetPoolFactoryV1(assetPoolFactory).create(
            address(this),
            id,
            _redeemTokenAmount
        );

        _addAssetPool(assetPool, id);

        _assetPoolId.increment();

        emit AssetPoolCreated(msg.sender, id, assetPool, _redeemTokenAmount);
    }

    // TODO optimize
    function _addAssetPool(address assetPool, uint256 id) private {
        _assetPools.add(assetPool);
        _assetPoolIds.add(id);
        _assetPoolIdToAssetPool[id] = assetPool;
    }
}
