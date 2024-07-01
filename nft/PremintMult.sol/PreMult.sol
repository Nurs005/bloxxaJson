// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PremintMult is ERC1155, Ownable {

    constructor(
        string memory uri,
        address account,
        uint id,
        uint amount,
        bytes memory data,
        address initialOwner
    ) ERC1155(uri) Ownable(initialOwner) {
        _mint(account, id, amount, data);
    }

    function mint(
        address account,
        uint id,
        uint amount,
        bytes memory data
    ) public onlyOwner {
        _mint(account, id, amount, data);
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function mintBatch(
        address to,
        uint[] memory ids,
        uint[] memory amounts,
        bytes memory data
    ) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }
    function burn(uint id, uint amount, address account) public onlyOwner{
        _burn(account, id, amount);
    }
    function burnBatch(uint[] memory ids, uint[] memory values, address account)public onlyOwner {
        _burnBatch(account, ids, values);
    }
}