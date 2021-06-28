// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";



contract GeoTokens is ERC721,Ownable {
    
    uint256 private tokenId;
    mapping (uint256 => tokenInfo) metaData;
    
    struct tokenInfo{
        string name;
        string location;
        string svg;
        uint8 status; //0 = sold, 1 = available
        uint256 price;
        uint16 layer;
    }
    
    mapping(uint16 => bool) layerLocked;
    mapping(address=>bool) approvedUsers;
    event layerLock(uint16 layerNumber,bool layerStatus);
    event NFTCreation(uint256 tokenID,tokenInfo Info);
    event NFTSale(address buyer,uint256 tokenId);
    
    constructor() ERC721("GeoTokens","GT"){
        tokenId = 1;
    }
    
    function ApproveUser(address UserAddress) external onlyOwner {
        approvedUsers[UserAddress] = true;
    }
    
    function isApprovedUser(address UserAddress) internal view returns(bool){
        return approvedUsers[UserAddress];
    }
    
    modifier onlyApprovedOrOwner(address UserAddress){
        require(UserAddress == owner() || approvedUsers[UserAddress],"GeoTokens : User is not owner or Approved");
        _;
    }
    //Set price of any NFT with token ID
    function SetPrice(uint256 tokenID,uint256 _price) external onlyApprovedOrOwner(msg.sender) {
        require(metaData[tokenID].status == 1,"GeoTokens : Can't change sold NFT's price");
        require(tokenID < tokenId,"GeoTokens : NFT doesn't exist");
        metaData[tokenID].price = _price;
    }
    
    function changeLayerLock(uint16 layerNumber,bool status) external onlyApprovedOrOwner(msg.sender){
        require(layerLocked[layerNumber] != status,"GeoTokens : Locked status doesn't change");
        layerLocked[layerNumber] = status;
        emit layerLock(layerNumber,status);
    }
    
    
    //Owner can mint a new NFT 
    function CreateNew(tokenInfo[] memory MetaData) external onlyApprovedOrOwner(msg.sender) {
        uint256 length = MetaData.length;
        uint256 j;
        for(j=0;j<length;j++){
            metaData[tokenId] = MetaData[j];
            tokenId = tokenId + 1;
        }
        
    }
    
    //Owner can retrieve ONE stored in contract
    function retrieve(address payable transferAddress) external onlyApprovedOrOwner(msg.sender){
        require(address(this).balance > 0,"GeoTokens: No Ether to retrieve");
        payable(transferAddress).transfer(address(this).balance);
    }
    
    
    //Users can pay prescribed amount and buy token of particular token ID
    function Buy(uint256 tokenID) external payable{
        require (tokenID < tokenId,"GeoTokens: Token doesn't exist");
        require (metaData[tokenID].status == 1,"GoeTokens: Token is already sold");
        require (!layerLocked[metaData[tokenID].layer],"GeoTokens: This layer is locked right now");
        require (msg.value >= metaData[tokenID].price, "GeoTokens: Pay equal to or more than set Price");
        metaData[tokenID].status = 0;//Token status is sold
        _safeMint(msg.sender, tokenID);
        emit NFTSale(msg.sender,tokenID);
    }
    
    //returns metadata based on token ID
    function getMetadata(uint256 tokenID) public view returns(tokenInfo memory){
        require(_exists(tokenID),"GeoTokens: metaData call for Nonexistent token");
        return metaData[tokenID];
    }
    
    //Returns metadata of all available NFTs
    function getAllNFT() public view returns(tokenInfo[] memory){
        tokenInfo[] memory metaInfo = new tokenInfo[](tokenId-1);
        uint i;
        for (i = 0; i < tokenId-1; i++) {
        metaInfo[i] = metaData[i+1];
        }
    return metaInfo;
    }
    
    
    
}