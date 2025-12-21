// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../Authorised.sol";

contract RootERC1155 is ERC1155URIStorage, Authorised, Ownable {
    address immutable public PREDICATE;

    modifier onlyPredicate() {
        require(msg.sender == PREDICATE, "RebelRunTicket: only predicate allowed");
        _;
    }

    constructor(address _predicate)
    Authorised(msg.sender)
    ERC1155("")
    {
        PREDICATE = _predicate;
    }

    function setBaseUri(string memory _uri) external onlyAuthorised {
        _setBaseURI(_uri);
    }

    function setUri(uint256 _id, string memory _uri) external onlyAuthorised {
        _setURI(_id, _uri);
    }

    function mint(address to, uint256 id, uint256 amount, bytes memory data) external
    onlyPredicate
    {
        _mint(to, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external
    onlyPredicate
    {
        _mintBatch(to, ids, amounts, data);
    }

    function burnFor(address _from, uint256 _id, uint256 _amount) external {
        require(isApprovedForAll(_from, msg.sender));
        _burn(_from, _id, _amount);
    }
}
