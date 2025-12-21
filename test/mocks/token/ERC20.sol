// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20("", "") {
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
