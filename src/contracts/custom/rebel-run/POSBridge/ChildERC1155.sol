pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "@redeemy/interfaces/IRewardPoolV1.sol";
import "@redeemy/interfaces/IAssetPoolV1.sol";
//import "@redeemy/interfaces/token/IERC1155RedeemTokenV1.sol";

contract ChildERC1155 is ERC1155URIStorage, Ownable, IERC1155Receiver {
    address public constant CHILD_CHAIN_MANAGER = 0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa;

    address public vrfConsumer;

    modifier onlyMinter() {
        address sender = msg.sender;
        require(
            sender == vrfConsumer ||
            IRewardPoolV1(IAssetPoolV1(sender).getRewardPool()).getOwner() == owner()
        , "ChildRebelRunRedeemToken: only minter allowed");
        _;
    }

    modifier onlyBurner() {
        _;
    }

    constructor(
        address _vrfConsumer
    )
    ERC1155("")
    {
        vrfConsumer = _vrfConsumer;
    }

    function setBaseURI(string memory _uri) external onlyOwner {
        _setBaseURI(_uri);
    }

    function setURI(uint256 _id, string memory _uri) external onlyOwner {
        _setURI(_id, _uri);
    }

    function mint(address _to, uint256 _id, uint256 _amount) external onlyMinter {
        _mint(_to, _id, _amount, "");
    }

    function burn() external onlyBurner {
        //    _burn(msg.sender,)
    }

    function deposit(address user, bytes calldata depositData) external {
        require(msg.sender == CHILD_CHAIN_MANAGER, "ChildRebelRunRedeemToken: only minter allowed");

        (
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
        ) = abi.decode(depositData, (uint256[], uint256[], bytes));

        require(
            user != address(0),
            "ChildRebelRunRedeemToken: INVALID_DEPOSIT_USER"
        );

        _mintBatch(user, ids, amounts, data);
    }

    function withdrawSingle(uint256 id, uint256 amount) external {
        _burn(_msgSender(), id, amount);
    }

    function withdrawBatch(uint256[] calldata ids, uint256[] calldata amounts) external {
        _burnBatch(_msgSender(), ids, amounts);
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {
        return ChildERC1155.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4) {
        return ChildERC1155.onERC1155BatchReceived.selector;
    }
}
