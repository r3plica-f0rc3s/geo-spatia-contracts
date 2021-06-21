// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract AccountNFT is ERC721,Ownable {
    
    uint256 private tokenId;
    uint256 private price;
    mapping (uint256 => tokeInfo) metaData;
    
    struct tokeInfo{
        string name;
        string location;
        string svg;
    }
    
    constructor() ERC721("GeoTokens","GT"){
        tokenId = 1;
        price = 1 ether;
    }
    
    
    function SetPrice(uint256 _price) external onlyOwner {
        price = _price;
    }
    
    function retrieve() external{
        require(address(this).balance > 0,"GeoTokens: No Ether to retrieve");
        payable(owner()).transfer(address(this).balance);
    }
    
    function Buy(tokeInfo memory _metaData) external payable{
        require (msg.value >= price, "GeoTokens: Pay equal to or more than set Price");
        _safeMint(_msgSender(), tokenId);
        metaData[tokenId] = _metaData;
        tokenId = tokenId + 1;
    }
    
    function getMetadata(uint256 tokenID) public view returns(tokeInfo memory){
        require(_exists(tokenID),"GeoTokens: metaData call for Nonexistent token");
        return metaData[tokenID];
    }
    
    
}