// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@redeemy/interfaces/IRewardPoolV1.sol";
import "@redeemy/interfaces/token/IERC20RedeemTokenV1.sol";

import "./RedeemTokenV1.sol";

contract ERC20RedeemTokenV1 is IERC20RedeemTokenV1, RedeemTokenV1, ERC20 {
    constructor(
        address _rewardPool, string memory _name, string memory _symbol
    )
    RedeemTokenV1(_rewardPool)
    ERC20(_name, _symbol)
    {
    }

    function mint(address to, uint256 amount)
    external
    onlyAssetPool
    {
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) external onlyAssetPool {
        _burn(to, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);

        require(!_blacklisted[from], "ERC20RedeemTokenV1: blacklisted");
    }
}
