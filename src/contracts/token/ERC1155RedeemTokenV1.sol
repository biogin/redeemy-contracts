// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";

import "@redeemy/interfaces/IRewardPoolV1.sol";
import "@redeemy/interfaces/token/IERC1155RedeemTokenV1.sol";

import "./RedeemTokenV1.sol";

contract ERC1155RedeemTokenV1 is IERC1155RedeemTokenV1, RedeemTokenV1, ERC1155URIStorage {
    modifier onlyValidAssetPool(address assetPool, uint256 id) {
        require(IRewardPoolV1(rewardPool).getAssetPoolById(id) == assetPool, "RedeemTokenV1: only asset pool allowed with correct asset pool id");
        _;
    }

    constructor(address _rewardPool, string memory uri_)
    RedeemTokenV1(_rewardPool)
    ERC1155(uri_)
    {}

    function setBaseUri(string memory _uri) external onlyAdmin {
        _setBaseURI(_uri);
    }

    function setUri(uint256 _id, string memory _uri) external onlyAdmin {
        _setURI(_id, _uri);
    }

    function mint(address to, uint256 id, uint256 amount, bytes memory data)
    external
    onlyValidAssetPool(msg.sender, id)
    {
        _mint(to, id, amount, data);
    }

    function burn(address from, uint256 id, uint256 amount)
    external
    onlyValidAssetPool(msg.sender, id)
    {
        _burn(from, id, amount);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        super._beforeTokenTransfer(
            operator,
            from,
            to,
            ids,
            amounts,
            data
        );
        require(!_blacklisted[from], "RedeemTokenV1: address is blacklisted");

        for (uint i = 0; i < ids.length; ++i) {
            require(IRewardPoolV1(rewardPool).getAssetPoolById(ids[i]) != address(0), "RedeemTokenV1: invalid id");
        }
    }
}
