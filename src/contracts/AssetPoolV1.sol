// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/console2.sol";

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "@openzeppelin/contracts/security/Pausable.sol";

import "@opengsn/contracts/src/ERC2771Recipient.sol";

import "@redeemy/interfaces/IRewardPoolV1.sol";
import "@redeemy/interfaces/token/IERC20RedeemTokenV1.sol";
import "@redeemy/interfaces/token/IERC1155RedeemTokenV1.sol";

contract AssetPoolV1 is IAssetPoolV1, Initializable, ERC165, ERC2771Recipient {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant AMOUNT_OF_ASSET_TYPES = 3;
    uint256 public constant MAX_REDEEM_TOKEN_AMOUNT = 10;

    IRewardPoolV1 REWARD_POOL;

    uint256 private _id;
    address private _rewardPool;
    uint256 private _redeemTokenAmount;
    uint256 private _totalNumberOfAssets;

    mapping(AssetType => mapping(address => AssetBox[])) private _assetBoxes;
    mapping(AssetType => EnumerableSet.AddressSet) private _contractAddresses;

    modifier onlyOwner() {
        require(msg.sender == REWARD_POOL.getOwner(), "AssetPoolV1: only owner allowed");
        _;
    }

    modifier onlyAdmin() {
        require(REWARD_POOL.isAdmin(msg.sender), "AssetPoolV1: only admin allowed");
        _;
    }

    modifier onlyActive() {
        require(REWARD_POOL.isActive(), "AssetPoolV1: reward pool status is not active");
        _;
    }

    modifier onlyTransferrer() {
        require(
            REWARD_POOL.isTransferrer(msg.sender) ||
            REWARD_POOL.isAdmin(msg.sender)
        , "AssetPoolV1: only transferrer allowed");
        _;
    }

    modifier onlyCustomRedeemMethod() {
        IRewardPoolV1.RedeemMethod method = REWARD_POOL.getRedeemMethod();
        require(
            method == IRewardPoolV1.RedeemMethod.CustomERC20 ||
            method == IRewardPoolV1.RedeemMethod.CustomERC1155
            , "AssetPoolV1: only transferable redeem method allowed");
        _;
    }

    modifier onlyVRFConsumer() {
        require(msg.sender == REWARD_POOL.getVRFConsumer(), "AssetPoolV1: only vrf consumer allowed");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    function initialize(
        address rewardPool_,
        uint256 id_,
        uint256 redeemTokenAmount_
    ) public payable initializer {
        require(redeemTokenAmount_ > 0);

        _id = id_;
        _rewardPool = rewardPool_;
        _redeemTokenAmount = redeemTokenAmount_;

        REWARD_POOL = IRewardPoolV1(_rewardPool);

        _setTrustedForwarder(REWARD_POOL.getTrustedForwarder());
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view override (IERC165, ERC165) returns (bool) {
        return interfaceId == type(IAssetPoolV1).interfaceId ||
        interfaceId == type(IERC2771Recipient).interfaceId ||
        super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IAssetPoolV1
    function id() external view returns (uint256) {
        return _id;
    }

    /// @inheritdoc IAssetPoolV1
    function getRewardPool() external view returns (address) {
        return _rewardPool;
    }

    /// @inheritdoc IAssetPoolV1
    function getRedeemTokenAmount() external view returns (uint256) {
        return _redeemTokenAmount;
    }

    /// @inheritdoc IAssetPoolV1
    function setRedeemTokenAmount(uint256 amount) external onlyOwner {
        require(amount > 0, "AssetPoolV1: amount should be more than zero");

        _redeemTokenAmount = amount;

        emit RedeemTokenAmountChanged(msg.sender, amount);
    }

    function getContractsByAssetType(AssetType assetType) public view returns (address [] memory) {
        return _contractAddresses[assetType].values();
    }

    /// @inheritdoc IAssetPoolV1
    function getERC20Assets(address erc20Contract) external view returns (AssetBox[] memory) {
        return _getAssets(AssetType.ERC20, erc20Contract);
    }

    /// @inheritdoc IAssetPoolV1
    function getERC721Assets(address erc721Contract) external view returns (AssetBox[] memory) {
        return _getAssets(AssetType.ERC721, erc721Contract);
    }

    /// @inheritdoc IAssetPoolV1
    function getNativeTokenAssets() external view returns (AssetBox[] memory) {
        return _getAssets(AssetType.NativeToken, address(this));
    }

    function _getAssets(AssetType assetType, address contractAddress) private view returns (AssetBox[] memory) {
        return _assetBoxes[assetType][contractAddress];
    }

    /// @inheritdoc IAssetPoolV1
    function getDepositedAssetTypes() public view returns (AssetType [] memory) {
        AssetType [] memory assetTypes = new AssetType [](AMOUNT_OF_ASSET_TYPES);
        uint256 count = 0;

        if (_contractAddresses[AssetType.ERC721].length() > 0) {
            assetTypes[count] = AssetType.ERC721;
            ++count;
        }

        if (_contractAddresses[AssetType.ERC20].length() > 0) {
            assetTypes[count] = AssetType.ERC20;
            ++count;
        }

        if (_contractAddresses[AssetType.NativeToken].length() > 0) {
            assetTypes[count] = AssetType.NativeToken;
            ++count;
        }

        if (count != AMOUNT_OF_ASSET_TYPES) {
            assembly {
                mstore(assetTypes, count)
            }
        }

        return assetTypes;
    }

    /// @inheritdoc IAssetPoolV1
    function getTotalNumberOfAssets() public view returns (uint256) {
        return _totalNumberOfAssets;
    }

    /// @inheritdoc IAssetPoolV1
    function depositAssets(
        address [] calldata _erc20ContractAddresses,
        AssetBox [][] calldata _erc20Boxes,
        address [] calldata _erc721ContractAddresses,
        uint256 [][] calldata _erc721TokenIds,
        AssetBox [] calldata _nativeTokenBoxes
    ) payable external onlyAdmin {
        uint256 numberOfDepositedAssets = _calculateNumberOfAssets(
            _erc20Boxes,
            _erc721TokenIds,
            _nativeTokenBoxes
        );
        if (numberOfDepositedAssets < 1) {
            _revert(DepositAtLeastOneAsset.selector);
        }

        _totalNumberOfAssets += numberOfDepositedAssets;

        address admin = msg.sender;
        uint256 value = msg.value;

        uint256 nativeTokenAmount = _getNativeTokenAmount(_nativeTokenBoxes);

        require(value == nativeTokenAmount, "AssetPoolV1: invalid native token value sent");

        uint256 [] memory erc20Amounts = _getERC20Amounts(_erc20ContractAddresses, _erc20Boxes);

        _depositFungibleAssets(
            admin,
            _erc20ContractAddresses,
            erc20Amounts,
            _erc20Boxes,
            _nativeTokenBoxes,
            value
        );

        _depositERC721Assets(
            admin,
            _erc721ContractAddresses,
            _erc721TokenIds
        );

        _mintRedeemTokens(numberOfDepositedAssets);

        emit AssetsDeposited(admin, _erc20ContractAddresses, _erc20Boxes, _erc721ContractAddresses, _erc721TokenIds, _nativeTokenBoxes, numberOfDepositedAssets);
    }

    /// @inheritdoc IAssetPoolV1
    function withdrawAssets(
        address[] calldata erc20ContractAddresses,
        AssetBox[][] calldata erc20Boxes,

        address[] calldata erc721ContractAddresses,
        uint256[][] calldata erc721TokenIds,

        AssetBox[] calldata nativeTokenBoxes
    ) external onlyOwner {
        uint256 numberOfWithdrawnAssets = _withdrawErc20Assets(erc20ContractAddresses, erc20Boxes) +
        _withdrawErc721Assets(erc721ContractAddresses, erc721TokenIds) +
        _withdrawNativeTokenAssets(nativeTokenBoxes);

        _totalNumberOfAssets -= numberOfWithdrawnAssets;

        _burnRedeemTokens(numberOfWithdrawnAssets);

        emit AssetsWithdrawn(msg.sender, erc20ContractAddresses, erc20Boxes, erc721ContractAddresses, erc721TokenIds, nativeTokenBoxes, numberOfWithdrawnAssets);
    }

    function transferRedeemTokenNumber(address to, uint256 number)
    external
    onlyTransferrer
    onlyCustomRedeemMethod
    {
        (
        IRewardPoolV1.RedeemMethod redeemMethod,
        address redeemTokenContractAddress
        ) = _getRedeemInfo();
        uint256 amount = number * _redeemTokenAmount;

        if (redeemMethod == IRewardPoolV1.RedeemMethod.CustomERC20) {
            IERC20RedeemTokenV1(redeemTokenContractAddress).transfer(to, amount);
        } else if (redeemMethod == IRewardPoolV1.RedeemMethod.CustomERC1155) {
            IERC1155RedeemTokenV1(redeemTokenContractAddress).safeTransferFrom(address(this), to, _id, amount, '');
        }

        emit RedeemTokenTransferred(
            msg.sender,
            to,
            _id,
            amount
        );
    }

    function transferRedeemTokenAmount(address to, uint256 amount)
    external
    onlyTransferrer
    onlyCustomRedeemMethod
    {
        (
        IRewardPoolV1.RedeemMethod redeemMethod,
        address redeemTokenContractAddress
        ) = _getRedeemInfo();

        if (redeemMethod == IRewardPoolV1.RedeemMethod.CustomERC20) {
            IERC20RedeemTokenV1(redeemTokenContractAddress).transfer(to, amount);
        } else if (redeemMethod == IRewardPoolV1.RedeemMethod.CustomERC1155) {
            IERC1155RedeemTokenV1(redeemTokenContractAddress).safeTransferFrom(address(this), to, _id, amount, '');
        }

        emit RedeemTokenTransferred(
            msg.sender,
            to,
            _id,
            amount
        );
    }

    /// @inheritdoc IAssetPoolV1
    function redeemAsset(uint256 amountOfAssetsToRedeem) external onlyActive {
        // TODO probably should check for VRF balance
        if (amountOfAssetsToRedeem < 1) {
            _revert(RedeemAtLeastOneAsset.selector);
        }

        if (amountOfAssetsToRedeem > REWARD_POOL.getMaxNumberOfRewardsPerTx()) {
            _revert(RedeemMoreThanMaxAmount.selector);
        }

        if (amountOfAssetsToRedeem > _totalNumberOfAssets) {
            _revert(NotEnoughAssetsInThePool.selector);
        }

        _totalNumberOfAssets -= amountOfAssetsToRedeem;

        address receiver = _msgSender();

        (
        IRewardPoolV1.RedeemMethod redeemMethod,
        address redeemTokenContractAddress
        ) = _getRedeemInfo();

        uint256 requiredAmount = _redeemTokenAmount * amountOfAssetsToRedeem;

        if (redeemMethod == IRewardPoolV1.RedeemMethod.ExistingERC20) {
            IERC20RedeemTokenV1 erc20Token = IERC20RedeemTokenV1(redeemTokenContractAddress);

            _ensureCorrectERC20Input(receiver, erc20Token, requiredAmount);

            bool success = erc20Token.transferFrom(receiver, REWARD_POOL.getWithdrawAddress(), requiredAmount);

            if (!success)
                _revert(TransferFailed.selector);
        } else if (redeemMethod == IRewardPoolV1.RedeemMethod.CustomERC20) {
            IERC20RedeemTokenV1 erc20Token = IERC20RedeemTokenV1(redeemTokenContractAddress);

            if (erc20Token.balanceOf(receiver) < requiredAmount) _revert(InsufficientBalance.selector);

            erc20Token.burn(receiver, requiredAmount);
        } else if (redeemMethod == IRewardPoolV1.RedeemMethod.CustomERC1155) {
            IERC1155RedeemTokenV1 erc1155Token = IERC1155RedeemTokenV1(redeemTokenContractAddress);

            if (erc1155Token.balanceOf(receiver, _id) < requiredAmount)
                _revert(InsufficientBalance.selector);

            erc1155Token.burn(receiver, _id, requiredAmount);
        } else {
            // should never happen
            _revert(InvalidRedeemMethod.selector);
        }

        uint256 [] memory requestIds = new uint256[](amountOfAssetsToRedeem);

        for (uint i = 0; i < amountOfAssetsToRedeem; ++i) {
            requestIds[i] = REWARD_POOL.requestRandomWords(receiver);
        }

        emit RedeemAssetsRequested(receiver, requestIds);
    }

    /// @inheritdoc IAssetPoolV1
    function fulfillRedeemAsset(
        uint256 requestId,
        address receiver,
        uint256 [] memory words
    ) external onlyVRFConsumer returns (AssetType, address, uint256) {
        uint256 randomWordIndex = 0;
        AssetType [] memory assetTypes = getDepositedAssetTypes();

        AssetType assetType = assetTypes[words[randomWordIndex++] % assetTypes.length];

        (
        IRewardPoolV1.RedeemMethod redeemMethod,
        address redeemTokenContractAddress
        ) = _getRedeemInfo();

        if (assetType == AssetType.ERC20 || assetType == AssetType.NativeToken || assetType == AssetType.ERC721) {
            EnumerableSet.AddressSet storage _contracts = _contractAddresses[assetType];
            address contractAddress = _contracts.at(words[randomWordIndex++] % _contracts.length());

            AssetBox[] storage boxes = _assetBoxes[assetType][contractAddress];

            (uint256 boxIndex, bool isLastBox) = _getRandomBox(boxes, words[randomWordIndex++]);

            AssetBox memory box = _updateAssetBox(boxes, boxIndex);

            if (isLastBox) {
                _contracts.remove(contractAddress);
                delete _assetBoxes[assetType][contractAddress];
            }

            uint256 amountOrTokenId = box.amountOrTokenId;

            if (assetType == AssetType.ERC20) {
                require(IERC20(contractAddress).transfer(receiver, amountOrTokenId), "AssetPoolV1: ERC20 transfer failed");
            } else if (assetType == AssetType.NativeToken) {
                (bool sent,) = receiver.call{value : amountOrTokenId}("");
                require(sent, "AssetPoolV1: Native token transfer failed");
            } else if (assetType == AssetType.ERC721) {
                IERC721(contractAddress).safeTransferFrom(address(this), receiver, amountOrTokenId);
            }

            emit AssetRedeemed(requestId, receiver, contractAddress, box);

            return (assetType, contractAddress, amountOrTokenId);
        }

        // should never happen
        return _nullFulfillReturn(assetType);
    }

    function _depositERC721Assets(
        address admin,
        address [] calldata _erc721ContractAddresses,
        uint256 [][] calldata _erc721TokenIds
    ) private {
        require(_erc721ContractAddresses.length == _erc721TokenIds.length, "AssetPoolV1: invalid length");

        uint i;

        for (i = 0; i < _erc721ContractAddresses.length; ++i) {
            address contractAddress = _erc721ContractAddresses[i];
            AssetBox [] storage erc721Boxes = _assetBoxes[AssetType.ERC721][contractAddress];

            IERC721 erc721Contract = IERC721(contractAddress);

            require(erc721Contract.isApprovedForAll(admin, address(this)), "AssetPoolV1: erc721 not approved");

            if (!_contractAddresses[AssetType.ERC721].contains(contractAddress)) {
                _contractAddresses[AssetType.ERC721].add(contractAddress);
            }

            for (uint j = 0; j < _erc721TokenIds[i].length; ++j) {
                uint256 tokenId = _erc721TokenIds[i][j];

                erc721Contract.safeTransferFrom(admin, address(this), tokenId);

                erc721Boxes.push(AssetBox({
                    depositer: admin,
                    assetType: AssetType.ERC721,
                    numberOfCards: 1,
                    amountOrTokenId: tokenId
                }));
            }
        }
    }

    function _depositFungibleAssets(
        address admin,
        address [] calldata _erc20ContractAddresses,
        uint256 [] memory _erc20Amounts,

        AssetBox [][] calldata _erc20Boxes,

        AssetBox [] calldata _nativeBoxes,
        uint256 value
    ) private {
        _handleErc20TokenDeposits(admin, _erc20ContractAddresses, _erc20Amounts, _erc20Boxes);
        _handleNativeTokenDeposits(admin, _nativeBoxes, value);
    }

    function _handleErc20TokenDeposits(
        address admin,
        address [] calldata _erc20ContractAddresses,
        uint256 [] memory _erc20Amounts,

        AssetBox [][] calldata _erc20Boxes
    ) private {
        for (uint i = 0; i < _erc20ContractAddresses.length; ++i) {
            address erc20Contract = _erc20ContractAddresses[i];
            uint256 amount = _erc20Amounts[i];

            require(IERC20(erc20Contract).allowance(admin, address(this)) >= amount, "AssetPoolV1: erc20 not approved");
            require(IERC20(erc20Contract).transferFrom(admin, address(this), amount), "AssetPoolV1: erc20 transfer failed");

            AssetBox [] storage erc20Boxes = _assetBoxes[AssetType.ERC20][erc20Contract];

            if (!_contractAddresses[AssetType.ERC20].contains(erc20Contract)) {
                _contractAddresses[AssetType.ERC20].add(erc20Contract);
            }

            for (uint j = 0; j < _erc20Boxes[i].length; ++j) {
                AssetBox memory box = _erc20Boxes[i][j];
                box.depositer = admin;
                box.assetType = AssetType.ERC20;
                _updateOrAddBox(erc20Boxes, box);
            }
        }
    }

    function _handleNativeTokenDeposits(
        address admin,
        AssetBox [] calldata _nativeBoxes,
        uint256 value
    ) private {
        AssetBox [] storage nativeTokenBoxes = _assetBoxes[AssetType.NativeToken][address(this)];

        if (!_contractAddresses[AssetType.NativeToken].contains(address(this))) {
            _contractAddresses[AssetType.NativeToken].add(address(this));
        }

        for (uint i = 0; i < _nativeBoxes.length; ++i) {
            AssetBox memory box = _nativeBoxes[i];
            box.depositer = admin;
            box.assetType = AssetType.NativeToken;
            _updateOrAddBox(nativeTokenBoxes, box);
        }

        (bool success,) = address(this).call{value : value}("");

        require(success, "AssetPoolV1: transfer failed");
    }

    function _updateOrAddBox(AssetBox[] storage boxes, AssetBox memory box) private {
        bool boxFound = false;

        for (uint k = 0; k < boxes.length; ++k) {
            if (boxes[k].amountOrTokenId == box.amountOrTokenId) {
                boxes[k].numberOfCards += box.numberOfCards;
                boxFound = true;
                break;
            }
        }

        if (!boxFound) {
            boxes.push(box);
        }
    }

    function _mintRedeemTokens(uint256 numberOfDepositedAssets) private {
        IRewardPoolV1.RedeemMethod redeemMethod = REWARD_POOL.getRedeemMethod();
        uint256 redeemTokenAmountToMint = _redeemTokenAmount * numberOfDepositedAssets;

        if (redeemMethod == IRewardPoolV1.RedeemMethod.CustomERC20) {
            IERC20RedeemTokenV1 erc20Token = IERC20RedeemTokenV1(REWARD_POOL.getRedeemTokenContractAddress());
            erc20Token.mint(address(this), redeemTokenAmountToMint);
        } else if (redeemMethod == IRewardPoolV1.RedeemMethod.CustomERC1155) {
            IERC1155RedeemTokenV1 erc1155Token = IERC1155RedeemTokenV1(REWARD_POOL.getRedeemTokenContractAddress());
            erc1155Token.mint(address(this), _id, redeemTokenAmountToMint, "");
        }
    }

    function _burnRedeemTokens(uint256 numberOfWithdrawnAssets) private {
        IRewardPoolV1.RedeemMethod redeemMethod = REWARD_POOL.getRedeemMethod();
        uint256 redeemTokenAmountToBurn = _redeemTokenAmount * numberOfWithdrawnAssets;

        if (redeemMethod == IRewardPoolV1.RedeemMethod.CustomERC20) {
            IERC20RedeemTokenV1(REWARD_POOL.getRedeemTokenContractAddress()).mint(address(this), redeemTokenAmountToBurn);
        } else if (redeemMethod == IRewardPoolV1.RedeemMethod.CustomERC1155) {
            IERC1155RedeemTokenV1(REWARD_POOL.getRedeemTokenContractAddress()).mint(address(this), _id, redeemTokenAmountToBurn, "");
        }
    }

    function _updateAssetBox(AssetBox [] storage boxes, uint256 index) private returns (AssetBox memory) {
        AssetBox memory box = boxes[index];

        if (box.numberOfCards > 1) {
            boxes[index].numberOfCards--;
        } else {
            _removeAssetBox(boxes, index);
        }

        return box;
    }

    function _removeAssetBox(AssetBox[] storage boxes, uint256 index) private {
        uint256 lastIndex = boxes.length - 1;

        if (index != lastIndex) {
            boxes[index] = boxes[lastIndex];
        }

        boxes.pop();
    }

    function _getERC20Amounts(
        address [] calldata _erc20Contracts,
        AssetBox [][] calldata _erc20Boxes
    ) private returns (uint256 [] memory) {
        uint256 [] memory amounts = new uint256[](_erc20Contracts.length);
        uint256 total = 0;

        for (uint i = 0; i < _erc20Contracts.length; ++i) {
            for (uint j = 0; j < _erc20Boxes[i].length; ++j) {
                AssetBox calldata box = _erc20Boxes[i][j];
                total += box.amountOrTokenId * box.numberOfCards;
            }

            amounts[i] = total;
            total = 0;
        }

        return amounts;
    }

    function _getNativeTokenAmount(
        AssetBox [] calldata _nativeTokenBoxes
    ) private returns (uint256) {
        uint256 amount = 0;

        for (uint i = 0; i < _nativeTokenBoxes.length; ++i) {
            AssetBox memory box = _nativeTokenBoxes[i];
            amount += box.amountOrTokenId * box.numberOfCards;
        }

        return amount;
    }

    function _calculateNumberOfAssets(
        AssetBox [][] calldata _erc20Boxes,
        uint256 [][] memory _erc721PoolTokenIds,
        AssetBox [] calldata _nativeTokenBoxes
    ) private pure returns (uint256) {
        uint256 amountOfAssets = 0;

        uint i;
        for (i = 0; i < _erc20Boxes.length; ++i) {
            for (uint j = 0; j < _erc20Boxes[i].length; ++j) {
                amountOfAssets += _erc20Boxes[i][j].numberOfCards;
            }
        }

        for (i = 0; i < _nativeTokenBoxes.length; ++i) {
            amountOfAssets += _nativeTokenBoxes[i].numberOfCards;
        }

        for (i = 0; i < _erc721PoolTokenIds.length; ++i) {
            amountOfAssets += _erc721PoolTokenIds[i].length;
        }

        return amountOfAssets;
    }

    function _ensureCorrectERC20Input(address receiver, IERC20RedeemTokenV1 redeemToken, uint256 requiredAmount) private {
        if (redeemToken.balanceOf(receiver) < requiredAmount) _revert(InsufficientBalance.selector);

        if (redeemToken.allowance(receiver, address(this)) < requiredAmount) _revert(InsufficientApproval.selector);
    }

    /* @dev here we should pick a random card from all the available cards in the boxes

        For example:
        Box N1 = { amountOfCards: 2: amount: 100$ }
        Box N2 = { amountOfCards: 10: amount: 20$ }

        Lay out cards(12 in total) sequentially like so:
        |1    2|  |3  4 ... 11  12|
        |Box N1|  |    Box N2     |

        Then we pick a random index between these indexes,

        totalAmountOfCards = sum((Box N1).amountOfCards + (Box N2).amountOfCards)

        randomCardIndex = randomWord % totalAmountOfCards

        iterate over all the cards and the first card index that matches the randomly chosen card index
        is the random box we'll use
    */
    function _getRandomBox(AssetBox [] storage boxes, uint256 randomWord) private view returns (uint256, bool) {
        (uint256 idx, bool isLast) = _getRandomBoxIndex(boxes, randomWord);

        return (idx, isLast);
    }

    function _getRandomBoxIndex(AssetBox [] memory boxes, uint256 randomWord) private pure returns (uint256, bool) {
        (uint256 randomCardIndex, bool isLast) = _getRandomCardIndex(boxes, randomWord);

        uint256 cumulativeCards = 0;
        for (uint i = 0; i < boxes.length; ++i) {
            cumulativeCards += boxes[i].numberOfCards;
            if (randomCardIndex < cumulativeCards) {
                return (i, isLast);
            }
        }

        revert();
    }

    /*
     * @return `cardIndex` random card index from the box plus `isLast` indicating whether this is the last box
     */
    function _getRandomCardIndex(AssetBox [] memory boxes, uint256 randomWord) private pure returns (uint256 cardIndex, bool isLast) {
        uint256 totalAmountOfCards = 0;

        for (uint i = 0; i < boxes.length; ++i) {
            totalAmountOfCards += boxes[i].numberOfCards;
        }

        return (randomWord % totalAmountOfCards, totalAmountOfCards == 1);
    }

    function _getRedeemInfo() private view returns (IRewardPoolV1.RedeemMethod, address) {
        return (REWARD_POOL.getRedeemMethod(), REWARD_POOL.getRedeemTokenContractAddress());
    }

    function _nullFulfillReturn(AssetType assetType) private pure returns (AssetType, address, uint256) {
        return (assetType, address(0), 0);
    }

    function _withdrawErc20Assets(
        address[] calldata erc20ContractAddresses,
        AssetBox[][] calldata erc20Boxes
    ) internal returns (uint256) {
        uint256 total = 0;

        for (uint i = 0; i < erc20ContractAddresses.length; ++i) {
            total += _withdrawErc20Asset(erc20ContractAddresses[i], erc20Boxes[i]);
        }

        return total;
    }

    function _withdrawErc20Asset(
        address erc20Contract,
        AssetBox[] calldata boxesToWithdraw
    ) private returns (uint256) {
        FungibleWithdrawInfo memory info = FungibleWithdrawInfo({
        totalToWithdraw : 0,
        boxToWithdraw : AssetBox(address(0), AssetType.ERC20, 0, 0),
        found : false,
        k : 0
        });
        AssetBox[] storage boxes = _assetBoxes[AssetType.ERC20][erc20Contract];

        for (uint i = 0; i < boxesToWithdraw.length; ++i) {
            info.boxToWithdraw = boxesToWithdraw[i];
            info.found = false;

            (info.found, info.k) = findErc20AssetBox(boxes, info.boxToWithdraw);

            require(info.found, "AssetPoolV1: box not found for withdrawal");

            IERC20(erc20Contract).transfer(info.boxToWithdraw.depositer, info.boxToWithdraw.amountOrTokenId * info.boxToWithdraw.numberOfCards);

            uint256 newNumberOfCards = boxes[info.k].numberOfCards - info.boxToWithdraw.numberOfCards;
            if (newNumberOfCards == 0) {
                _removeAssetBox(boxes, info.k);
            } else {
                boxes[info.k].numberOfCards = newNumberOfCards;
            }

            info.totalToWithdraw += info.boxToWithdraw.numberOfCards;
        }

        return info.totalToWithdraw;
    }

    function findErc20AssetBox(AssetBox[] storage boxes, AssetBox memory boxToWithdraw) private view returns (bool, uint256) {
        bool found = false;
        uint256 k = 0;

        for (; k < boxes.length && !found; ++k) {
            AssetBox memory storedBox = boxes[k];

            if (storedBox.amountOrTokenId == boxToWithdraw.amountOrTokenId) {
                require(storedBox.numberOfCards >= boxToWithdraw.numberOfCards, "AssetPoolV1: insufficient cards for withdrawal");
                found = true;
            }
        }

        if (found) {
            k -= 1;
        }

        return (found, k);
    }

    function _withdrawErc721Assets(
        address[] calldata erc721ContractAddresses,
        uint256[][] calldata erc721TokenIds
    ) internal returns (uint256) {
        uint256 total = 0;

        for (uint i = 0; i < erc721ContractAddresses.length; ++i) {
            total += _withdrawErc721Asset(erc721ContractAddresses[i], erc721TokenIds[i]);
        }

        return total;
    }

    function _withdrawErc721Asset(
        address erc721Contract,
        uint256[] calldata tokenIds
    ) private returns (uint256) {
        NonFungibleWithdrawInfo memory info = NonFungibleWithdrawInfo({
        totalToWithdraw : 0,
        tokenId : 0,
        found : false,
        k : 0
        });
        AssetBox[] storage boxes = _assetBoxes[AssetType.ERC721][erc721Contract];

        for (uint j = 0; j < tokenIds.length; ++j) {
            info.tokenId = tokenIds[j];
            info.found = false;

            (info.found, info.k) = findErc721AssetBox(boxes, info.tokenId);

            require(info.found, "AssetPoolV1: token ID not found for withdrawal");

            AssetBox memory box = boxes[info.k];

            IERC721(erc721Contract).transferFrom(address(this), boxes[info.k].depositer, info.tokenId);
            _removeAssetBox(boxes, info.k);

            info.totalToWithdraw += 1;
        }

        return info.totalToWithdraw;
    }

    function findErc721AssetBox(AssetBox[] storage boxes, uint256 tokenId) private view returns (bool, uint256) {
        bool found = false;
        uint256 k = 0;

        for (; k < boxes.length && !found; ++k) {
            if (boxes[k].amountOrTokenId == tokenId) {
                found = true;
            }
        }

        if (found) {
            k -= 1;
        }

        return (found, k);
    }

    function _withdrawNativeTokenAssets(
        AssetBox[] memory nativeTokenBoxes
    ) internal returns (uint256) {
        FungibleWithdrawInfo memory info = FungibleWithdrawInfo({
        totalToWithdraw : 0,
        boxToWithdraw : AssetBox(address(0), AssetType.NativeToken, 0, 0),
        found : false,
        k : 0
        });
        AssetBox[] storage boxes = _assetBoxes[AssetType.NativeToken][address(this)];

        for (uint i = 0; i < nativeTokenBoxes.length; ++i) {
            info.boxToWithdraw = nativeTokenBoxes[i];
            info.found = false;

            (info.found, info.k) = findNativeTokenAssetBox(boxes, info.boxToWithdraw);

            require(info.found, "AssetPoolV1: native token box not found for withdrawal");

            payable(info.boxToWithdraw.depositer).transfer(info.boxToWithdraw.amountOrTokenId * info.boxToWithdraw.numberOfCards);

            uint256 newNumberOfCards = boxes[info.k].numberOfCards - info.boxToWithdraw.numberOfCards;
            if (newNumberOfCards == 0) {
                _removeAssetBox(boxes, info.k);
            } else {
                boxes[info.k].numberOfCards = newNumberOfCards;
            }

            info.totalToWithdraw += info.boxToWithdraw.numberOfCards;
        }

        return info.totalToWithdraw;
    }

    function findNativeTokenAssetBox(AssetBox[] storage boxes, AssetBox memory boxToWithdraw) private view returns (bool, uint256) {
        bool found = false;
        uint256 k = 0;

        for (; k < boxes.length && !found; ++k) {
            AssetBox memory storedBox = boxes[k];

            if (storedBox.amountOrTokenId == boxToWithdraw.amountOrTokenId) {
                require(storedBox.numberOfCards >= boxToWithdraw.numberOfCards, "AssetPoolV1: insufficient cards for withdrawal");
                found = true;
            }
        }

        if (found) {
            k -= 1;
        }

        return (found, k);
    }

    /// @inheritdoc IERC721Receiver
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(
        address operator,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external view returns (bytes4) {
        if (operator == address(this)) {
            return IERC1155Receiver.onERC1155Received.selector;
        }
        return 0;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external view returns (bytes4) {
        if (operator == address(this)) {
            return IERC1155Receiver.onERC1155BatchReceived.selector;
        }
        return 0;
    }

    /**
     * @dev For more efficient reverts.
     */
    function _revert(bytes4 errorSelector) internal {
        assembly {
            mstore(0x00, errorSelector)
            revert(0x00, 0x04)
        }
    }
}
