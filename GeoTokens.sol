// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";



contract GeoTokens is ERC721,Ownable {
    
    uint256 private tokenId;
    mapping (uint256 => tokeInfo) metaData;
    
    struct tokeInfo{
        string name;
        string location;
        string svg;
        uint8 status; //0 = sold, 1 = available
        uint256 price;
        uint16 layer;
    }
    
    mapping(uint16 => bool) layerLocked;
    
    event layerLock(uint16 layerNumber,bool layerStatus);
    event NFTCreation(uint256 tokenID,tokeInfo Info);
    event NFTSale(address buyer,uint256 tokenId);
    
    constructor() ERC721("GeoTokens","GT"){
        tokenId = 1;
    }
    
    //Set price of any NFT with token ID
    function SetPrice(uint256 tokenID,uint256 _price) external onlyOwner {
        require(metaData[tokenID].status == 1,"GeoTokens : Can't change sold NFT's price");
        require(tokenID < tokenId,"GeoTokens : NFT doesn't exist");
        metaData[tokenID].price = _price;
    }
    
    function changeLayerLock(uint16 layerNumber,bool status) external onlyOwner{
        require(layerLocked[layerNumber] != status,"GeoTokens : Locked status doesn't change");
        layerLocked[layerNumber] = status;
        emit layerLock(layerNumber,status);
    }
    
    //Owner can mint a new NFT 
    function CreateNew(tokeInfo[] memory MetaData) external onlyOwner{
        uint256 length = MetaData.length;
        uint256 j;
        for(j=0;j<length;j++){
            metaData[tokenId] = MetaData[j];
            //emit NFTCreation(tokenId,MetaData[tokenId]);
            tokenId = tokenId + 1;
        }
        
    }
    
    //Owner can retrieve ONE stored in contract
    function retrieve(address payable transferAddress) external onlyOwner{
        require(address(this).balance > 0,"GeoTokens: No Ether to retrieve");
        payable(transferAddress).transfer(address(this).balance);
    }
    
    
    //Users can pay prescribed amount and buy token of particular token ID
    function Buy(uint256 tokenID) external payable{
        require (tokenID < tokenId,"GeoTokens: Token doesn't exist");
        require (metaData[tokenID].status == 1,"GoeTokens: Token is already sold");
        require (!layerLocked[metaData[tokenID].layer],"GeoTokens: This layer is locked right now");
        require (msg.value >= metaData[tokenID].price, "GeoTokens: Pay equal to or more than set Price");
        _safeMint(msg.sender, tokenID);
        metaData[tokenID].status = 0; //Token status is sold
        emit NFTSale(msg.sender,tokenID);
        
    }
    
    //returns metadata based on token ID
    function getMetadata(uint256 tokenID) public view returns(tokeInfo memory){
        require(_exists(tokenID),"GeoTokens: metaData call for Nonexistent token");
        return metaData[tokenID];
    }
    
    //Returns metadata of all available NFTs
    function getAllNFT() public view returns(tokeInfo[] memory){
        tokeInfo[] memory metaInfo = new tokeInfo[](tokenId-1);
        uint i;
        for (i = 0; i < tokenId-1; i++) {
        metaInfo[i] = metaData[i+1];
        }
    return metaInfo;
    }
    
    
    
}