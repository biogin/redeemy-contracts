// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@chiru-labs/contracts/ERC721A.sol";

contract MockERC721 is ERC721A("", "") {
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }

    function batchBurn(uint256 [] memory tokenIds) public {
        for (uint i = 0; i < tokenIds.length; ++i) {
            _burn(tokenIds[i]);
        }
    }
}

//0xa21baEF5060eaa7bd9e33D7d182674ce1241902C,1,0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed,0x326C977E6efc84E512bB9C30f76E30c160eD06FB
//
//[0x520e0e06D386F2Ad5C2B60e9D8b647AF945c646A,0x520e0e06D386F2Ad5C2B60e9D8b647AF945c646A],[27,28]
//
//[0x520e0e06D386F2Ad5C2B60e9D8b647AF945c646A,0x520e0e06D386F2Ad5C2B60e9D8b647AF945c646A,0x520e0e06D386F2Ad5C2B60e9D8b647AF945c646A],[33,34,35]
