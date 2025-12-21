// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IERC1155RedeemTokenV1 is IERC1155 {
    function mint(address addr, uint256 id, uint256 amount, bytes memory) external;

    function burn(address, uint256, uint256) external;
}
