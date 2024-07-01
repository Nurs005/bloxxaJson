// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Premint721 is ERC721URIStorage, Ownable {
    uint256 public _nextTokenId;

    constructor(
        address initialOwner,
        string memory _name,
        string memory _symbol,
        address to,
        string memory _tokenURI
    ) ERC721(_name, _symbol)Ownable(initialOwner)  {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
    }

    function mint(address to, string memory _tokenURI) public onlyOwner {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
    }
    function burn(uint tokenId) public onlyOwner {
        _burn(tokenId);
    }
    
    
}