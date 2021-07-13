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
        uint256 highestBid;
        address bidderAddress;
        uint256 resalePrice;
        uint256 tokenID;
        uint256 resaleTime;
    } 
    
    struct bidInfo{
        uint256 highestBid;
        address bidderAddress;
    }
    
    
    resaleInfo[] public ResaleTokens;
    mapping(uint256=>uint256) public TokenSaleTime;
    mapping(uint256=>bidInfo) AuctionInfo;
    mapping(uint16 => bool) layerLocked;
    mapping(address=>bool) public approvedUsers;
    mapping(address=>uint256) public salesBalance;
    
    event layerLock(uint16 layerNumber,bool layerStatus);
    event NFTCreation(uint256 tokenID,tokenInfo Info,uint256 saleTime);
    event NFTBid(bidInfo newBid,uint256 tokenId);
    
    constructor() ERC721("GeoTokens","GT"){
        tokenId = 1;
        resaleId = 1;
    }
    
    function ApproveUser(address UserAddress) external onlyOwner {
        approvedUsers[UserAddress] = true;
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
    
    //Change locked status of layer
    function changeLayerLock(uint16 layerNumber,bool status) external onlyApprovedOrOwner(msg.sender){
        require(layerLocked[layerNumber] != status,"GeoTokens : Locked status doesn't change");
        layerLocked[layerNumber] = status;
        emit layerLock(layerNumber,status);
    }
    
    //Change end date of auction
    function changeSaleTime(uint256 tokenID,uint256 newDaysLater) external onlyApprovedOrOwner(msg.sender){
        require(metaData[tokenID].status == 1,"GeoTokens : Can't change auction end date for sold tokens");
        require(tokenID < tokenId,"GeoTokens : NFT doesn't exist");
        TokenSaleTime[tokenId] = block.timestamp + newDaysLater * 1 days;
    }
    
    //Owner can mint a new NFT and host for auction
    function CreateNew(tokenInfo[] memory MetaData,string[] memory svg,uint256[] memory DaysLater) external onlyApprovedOrOwner(msg.sender) {
        require(MetaData.length == svg.length,"GeoTokens: MetaData and Svg lenghts don't match");
        require(MetaData.length == DaysLater.length,"GeoTokens: MetaData and aunction days length don't match");
        uint256 length = MetaData.length;
        uint256 j;
        //store metadata, svg and unix sale datelimit 
        for(j=0;j<length;j++){
            metaData[tokenId+j] = MetaData[j];
            tokenSvg[tokenId+j] = svg[j];
            TokenSaleTime[tokenId+j] = block.timestamp + DaysLater[j] * 1 days;
            emit NFTCreation(tokenId,metaData[tokenId],TokenSaleTime[tokenId]);
            tokenId = tokenId + 1;
        }
    }
    
    //Get token SVG
    function GetTokenSVG(uint256 tokenID) public view returns(string memory){
        return tokenSvg[tokenID];
    }
    
    //Owner can retrieve ONE stored in contract
    function retrieve() external {
        require(salesBalance[msg.sender] > 0,"GeoTokens: No Ether to retrieve");
        uint256 balance = salesBalance[msg.sender];
        salesBalance[msg.sender] = 0;
        payable(msg.sender).transfer(balance);
    }
    
    
    function Bid(uint256 tokenID) external payable{
        require (tokenID < tokenId,"GeoTokens: Token doesn't exist");
        require (metaData[tokenID].status == 1,"GoeTokens: Token is already sold");
        require (!layerLocked[metaData[tokenID].layer],"GeoTokens: This layer is locked right now");
        require ((msg.value >= metaData[tokenID].price) && (msg.value >= AuctionInfo[tokenID].highestBid + 0.01 ether), "GeoTokens: Pay more than highest bidder");
        require(block.timestamp < TokenSaleTime[tokenID], "GeoTokens: Auction has already expired");
        bidInfo memory newBid;
        if(AuctionInfo[tokenID].bidderAddress != address(0)){
            newBid.highestBid = AuctionInfo[tokenID].highestBid;
            newBid.bidderAddress = AuctionInfo[tokenID].bidderAddress;
            AuctionInfo[tokenID].highestBid = 0;
            AuctionInfo[tokenID].bidderAddress = address(0);
            payable(newBid.bidderAddress).transfer(newBid.highestBid);
        }
        newBid.highestBid = msg.value;
        newBid.bidderAddress = msg.sender;
        AuctionInfo[tokenID] = newBid;
        emit NFTBid(AuctionInfo[tokenID],tokenID);
        
    }
    
    //Users can retrieve tokens won in the auction
    function RetrieveNFT(uint256 tokenID) external payable{
        require(AuctionInfo[tokenID].bidderAddress == msg.sender,"GeoTokens: User is not auction winner for this token");
        require(metaData[tokenID].status == 1,"GeoTokens: NFT has alread been sold");
        metaData[tokenID].status = 0;//Token status is sold
        salesBalance[owner()] += AuctionInfo[tokenID].highestBid;
        delete TokenSaleTime[tokenID];
        _safeMint(msg.sender, tokenID);
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
    
    //make pure frontend ?
    function enableResale() external {
        setApprovalForAll(address(this),true);
    }
    
    //Make pure frontend??
    function disableResale() external {
        setApprovalForAll(address(this),false);
    }
    
    function putTokenForResale(uint256 price,uint256 TokenID,uint256 daysAfter) external {
        require(ownerOf(TokenID) == msg.sender,"GeoTokens: User is not the owner of this NFT");
        resaleInfo memory newInfo;
        newInfo.resalePrice = price;
        newInfo.tokenID = TokenID;
        newInfo.resaleTime = block.timestamp + daysAfter * 1 days;
        ResaleTokens.push(newInfo);
    }
    
    function bidResale(uint256 resaleID,uint256 TokenID) external payable{
        require(ResaleTokens[resaleID].tokenID == TokenID, "GeoTokens: Token ID mismatch");
        require(block.timestamp < ResaleTokens[resaleID].resaleTime, "GeoTokens: Auction has ended");
        require(ResaleTokens[resaleID].highestBid < msg.value + 0.01 ether,"GeoTokens: You need to send amount more than previous bid");
        address Bidder;
        uint256 bid;
        if(ResaleTokens[resaleID].bidderAddress != address(0)){
            Bidder = ResaleTokens[resaleID].bidderAddress;
            bid = ResaleTokens[resaleID].highestBid;
            ResaleTokens[resaleID].bidderAddress = address(0);
            ResaleTokens[resaleID].highestBid = 0;
            payable(Bidder).transfer(bid);
        }
        ResaleTokens[resaleID].bidderAddress = msg.sender;
        ResaleTokens[resaleID].highestBid = msg.value;
        
    }
    
    function RetrieveReSale(uint256 resaleID,uint256 TokenID) external{
        require(ResaleTokens[resaleID].tokenID == TokenID, "GeoTokens: Token ID mismatch");
        require(block.timestamp > ResaleTokens[resaleID].resaleTime, "GeoTokens: Auction has not ended yet");
        require(ResaleTokens[TokenID].bidderAddress == msg.sender,"GeoTokens: User is not the highest bidder");
        salesBalance[ownerOf(TokenID)] += ResaleTokens[resaleID].highestBid;
        safeTransferFrom(ownerOf(TokenID),msg.sender,TokenID);
        delete ResaleTokens[resaleID];
    }
    
}