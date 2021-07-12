// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";



contract GeoTokens is ERC721,Ownable {
    
    uint256 private tokenId;
    uint256 private resaleId;
    mapping (uint256 => tokenInfo) metaData;
    mapping (uint256 => string) tokenSvg;
    
    struct tokenInfo{
        string name;
        string location;
        uint8 status; //0 = sold, 1 = available
        uint256 price;
        uint16 layer;
    }
    
    struct resaleInfo{
        bool reserved;
        uint256 resalePrice;
        uint256 tokenID;
    } 
    
    resaleInfo[] private ResaleTokens;
    
    mapping(uint16 => bool) layerLocked;
    mapping(address=>bool) approvedUsers;
    event layerLock(uint16 layerNumber,bool layerStatus);
    event NFTCreation(uint256 tokenID,tokenInfo Info);
    event NFTSale(address buyer,uint256 tokenId);
    
    constructor() ERC721("GeoTokens","GT"){
        tokenId = 1;
        resaleId = 1;
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
    function CreateNew(tokenInfo[] memory MetaData,string[] memory svg) external onlyApprovedOrOwner(msg.sender) {
        require(MetaData.length == svg.length,"GeoTokens: MetaData and Svg lenghts don't match");
        uint256 length = MetaData.length;
        uint256 j;
        for(j=0;j<length;j++){
            metaData[tokenId] = MetaData[j];
            tokenSvg[tokenId] = svg[j];
            emit NFTCreation(tokenId,metaData[tokenId]);
            tokenId = tokenId + 1;
        }
    }
    
    //Get token SVG
    function GetTokenSVG(uint256 tokenID) public view returns(string memory){
        return tokenSvg[tokenID];
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
    
    function getTotalNFTs() external view returns(uint256){
        return tokenId-1;
    }
    
    //Returns metadata of all available NFTs
    function getAllNFT(uint256 len,uint256 index) public view returns(tokenInfo[] memory,bool){
        require(index < tokenId,"GeoTokens: Index needs to be less (or equal to) total NFTs");
        require(index > 0,"GeoTokens: Index start from 1");
        require(len > 0,"GeoTokens: length needs to be greater than 0");
        bool isEnd;
        uint256 endVal;
        uint256 length;
        if(index + len  >= tokenId){
            endVal = tokenId-1;
            length = endVal-index + 1;
            isEnd = true;
        }
        else{
            endVal = index + len;
            length = len;
            isEnd = false;
        }
        tokenInfo[] memory metaInfo = new tokenInfo[](length);
        
        uint i;
        for (i = 0; i < length; i++) {
        metaInfo[i] = metaData[index+i];
        }
    return (metaInfo,isEnd);
    }
    
    function getUserOwnedNFT() external view returns(tokenInfo[] memory){
        uint256 length = balanceOf(msg.sender);
        tokenInfo[] memory metaInfo = new tokenInfo[](length);
        uint i;
        uint j = 0;
        for (i = 1; i < tokenId; i++) {
            if(j==length){
                break;
            }
            if(_exists(i)){
                if(ownerOf(i) == msg.sender)
                {
                metaInfo[j] = metaData[i];
                j += 1;
                }
            }
            
        }
        return metaInfo;
    }
    
    function enableResale() external {
        setApprovalForAll(address(this),true);
    }
    
    function disableResale() external {
        setApprovalForAll(address(this),false);
    }
    
    function putTokenForResale(bool isReserved,uint256 price,uint256 TokenID) external {
        require(ownerOf(TokenID) == msg.sender,"GeoTokens: User is not the owner of NFT");
        resaleInfo memory newInfo;
        newInfo.reserved = isReserved;
        newInfo.resalePrice = price;
        newInfo.tokenID = TokenID;
        ResaleTokens.push(newInfo);
    }
    
    function reSale(uint256 resaleID,uint256 TokenID) public payable{
        require(ResaleTokens[resaleID].tokenID == TokenID, "GeoTokens: Token ID mismatch");
        require(msg.value == ResaleTokens[resaleID].resalePrice,"Price is not equal to seller defined price");
        transferFrom(ownerOf(TokenID),msg.sender,TokenID);
    }
    
    function contractBalance() external view returns(uint256){
        return address(this).balance;
    }
    
}