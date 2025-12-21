// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Authorised {
    mapping(address => bool) private _authorised;

    address public immutable _owner;

    modifier onlyAuthorised() {
        address sender = msg.sender;
        require(_authorised[sender] || sender == _owner, "Authorised: only authorised caller allowed");
        _;
    }

    constructor(address owner_) {
        _owner = owner_;
    }

    function setAuthorised(address _caller, bool _isAuthorised) external {
        require(msg.sender == _owner);
        _authorised[_caller] = _isAuthorised;
    }

    function getAuthorised(address _addr) external view returns (bool) {
        return _authorised[_addr];
    }
}
