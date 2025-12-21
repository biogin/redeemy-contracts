// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LinkToken {
    function allowance(address owner, address spender) external view returns (uint256 remaining) {
        return 0;
    }

    function approve(address spender, uint256 value) external returns (bool success) {
        return true;
    }

    function balanceOf(address owner) external view returns (uint256 balance) {
        return 0;
    }

    function decimals() external view returns (uint8 decimalPlaces) {
        return 18;
    }

    function decreaseApproval(address spender, uint256 addedValue) external returns (bool success) {
        return true;
    }

    function name() external view returns (string memory tokenName) {
        return "link";
    }

    function symbol() external view returns (string memory tokenSymbol) {
        return "LINK";
    }

    function totalSupply() external view returns (uint256 totalTokensIssued) {
        return 18 ether;
    }

    function transfer(address to, uint256 value) external returns (bool success) {
        return true;
    }

    function transferAndCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bool success) {
        return true;
    }

    function transferFrom(
        address ,
        address ,
        uint256
    ) external returns (bool success) {
        return true;
    }
}
