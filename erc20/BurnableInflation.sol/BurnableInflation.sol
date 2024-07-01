// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BurnableInflation is ERC20, Ownable {
    constructor(
        string memory name,
        string memory symbol_,
        address initialOwner
    ) ERC20(name, symbol_) Ownable(initialOwner){}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}