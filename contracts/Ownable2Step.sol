// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Ownable2Step is Ownable {
    address private _pendingOwner;

    event OwnershipTransferInitiated(address indexed pendingOwner);
    event OwnershipTransferCompleted(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor()Ownable(msg.sender){}

    function transferOwnership(address newOwner) public virtual onlyOwner override {
        require(
            newOwner != address(0),
            "Ownable2Step: new owner is the zero address"
        );
        _pendingOwner = newOwner;
        emit OwnershipTransferInitiated(_pendingOwner);
    }

    function acceptOwnership() public {
        require(
            msg.sender == _pendingOwner,
            "Ownable2Step: caller is not the pending owner"
        );
        emit OwnershipTransferCompleted(owner(), _pendingOwner);
        _transferOwnership(_pendingOwner);
    }
}
