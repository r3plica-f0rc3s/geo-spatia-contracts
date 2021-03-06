// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.3/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.3/contracts/access/Ownable.sol";



contract GeoTokens is ERC721,Ownable {
    
    //Structs
    struct tokenInfo{
        string name;
        string location;
        uint8 status; //0 = sold, 1 = available, 2 = on resale
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
    
    //Primary NFT
    uint256 private tokenId;
    mapping (uint256 => tokenInfo) metaData;
    mapping (uint256 => string) tokenSvg;
    mapping(uint256=>uint256) public TokenSaleTime;
    mapping(uint256=>bidInfo) public AuctionInfo;
    
    //Admin
    mapping(address=>bool) public approvedUsers;
    mapping(uint16 => bool) layerLocked;
    mapping(address=>uint256) public salesBalance;
    
    //Resale
    uint256 private resaleId;
    mapping(uint256 =>resaleInfo) public ResaleTokens;
    
    //evets
    event layerLock(uint16 layerNumber,bool layerStatus);
    event NFTCreation(uint256 tokenID,tokenInfo Info,uint256 saleTime,uint256 creationTime);
    event NFTBid(bidInfo newBid,uint256 tokenId);
    event ResaleCreation(uint256 tokenID,uint256 resaleID,resaleInfo Info,uint256 creationTime);
    event ResaleBid(resaleInfo latestInfo,uint256 resaleId,uint256 tokenID);
    event SaleRetrieve(address UserAddress, uint256 tokenID);
    event ResaleRetrieve(address previousOwner,address newOwner, uint256 resaleID,uint256 tokenID);
    event ResaleRemoved(uint256 resaleID,uint256 tokenID);
    
    constructor() ERC721("GeoTokens","GT"){
        tokenId = 1;
        resaleId = 1;
    }
    
    //Admin functions
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
    function ChangeLayerLock(uint16 layerNumber,bool status) external onlyApprovedOrOwner(msg.sender){
        require(layerLocked[layerNumber] != status,"GeoTokens : Locked status doesn't change");
        layerLocked[layerNumber] = status;
        emit layerLock(layerNumber,status);
    }
    
    //Change end date of auction
    function ChangeSaleTime(uint256 tokenID,uint256 newDaysLater) external onlyApprovedOrOwner(msg.sender){
        require(metaData[tokenID].status == 1,"GeoTokens : Can't change auction end date for sold tokens");
        require(tokenID < tokenId,"GeoTokens : NFT doesn't exist");
        TokenSaleTime[tokenId] = block.timestamp + newDaysLater * 1 seconds;
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
            TokenSaleTime[tokenId+j] = block.timestamp + DaysLater[j] * 1 seconds;
            emit NFTCreation(tokenId,metaData[tokenId],TokenSaleTime[tokenId],block.timestamp);
            tokenId = tokenId + 1;
        }
    }
    
    //Sales
    
    
    //Get token SVG
    function GetTokenSVG(uint256 tokenID) public view returns(string memory){
        return tokenSvg[tokenID];
    }
    
    //Make a bid
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
    
    //Users can retrieve NFTs won in the auction
    function RetrieveNFT(uint256[] memory tokenID) external{
        uint256 length = tokenID.length;
        uint256 i;
        for(i=0;i<length;i++)
        {
            require(AuctionInfo[tokenID[i]].bidderAddress == msg.sender,"GeoTokens: User is not auction winner for this token");
            require(metaData[tokenID[i]].status == 1,"GeoTokens: NFT has alread been sold");
            require(TokenSaleTime[tokenID[i]] < block.timestamp,"GeoTokens: Auction has not ended yet");
        }
        
        for(i=0;i<length;i++){
            metaData[tokenID[i]].status = 0;//Token status is sold
            salesBalance[owner()] += AuctionInfo[tokenID[i]].highestBid;
            delete TokenSaleTime[tokenID[i]];
            delete AuctionInfo[tokenID[i]];
            _safeMint(msg.sender, tokenID[i]);
            emit SaleRetrieve(msg.sender,tokenID[i]);
        }
        
    }
    
    
    //Users can retrieve ONE stored in contract against their sales balance
    function Retrieve() external {
        require(salesBalance[msg.sender] > 0,"GeoTokens: No Ether to retrieve");
        uint256 balance = salesBalance[msg.sender];
        salesBalance[msg.sender] = 0;
        payable(msg.sender).transfer(balance);
    }
    
    
    
    
    //returns metadata based on token ID
    function GetMetadata(uint256 tokenID) public view returns(tokenInfo memory){
        require(tokenID < tokenId,"GeoTokens: metaData call for Nonexistent token");
        return metaData[tokenID];
    }
    
    function GetTotalNFTs() external view returns(uint256){
        return tokenId-1;
    }
    
    function GetUserOwnedNFT() external view returns(tokenInfo[] memory){
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
    
    //Resale
    function PutTokenForResale(uint256 price,uint256 TokenID,uint256 daysAfter) external {
        require(ownerOf(TokenID) == msg.sender,"GeoTokens: User is not the owner of this NFT");
        require(metaData[TokenID].status != 2,"GeoTokens: Token is already on re sale");
        if(!isApprovedForAll(msg.sender,address(this))){
            setApprovalForAll(owner(),true);
        }
        resaleInfo memory newInfo;
        newInfo.resalePrice = price;
        newInfo.tokenID = TokenID;
        newInfo.resaleTime = block.timestamp + daysAfter * 1 seconds;
        ResaleTokens[resaleId] = newInfo;
        metaData[TokenID].status = 2;
        emit ResaleCreation(TokenID,resaleId,newInfo,block.timestamp);
        resaleId += 1;
        
    }
    
    function BidResale(uint256 resaleID,uint256 TokenID) external payable{
        require(ResaleTokens[resaleID].tokenID == TokenID, "GeoTokens: Token ID mismatch");
        require(block.timestamp < ResaleTokens[resaleID].resaleTime, "GeoTokens: Auction has ended");
        require(msg.value > ResaleTokens[resaleID].resalePrice, "GeoTokens: Bid can't be lower than initial price");
        require(ResaleTokens[resaleID].highestBid + 0.01 ether < msg.value ,"GeoTokens: You need to send amount more than previous bid");
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
        emit ResaleBid(ResaleTokens[resaleID],resaleID,TokenID);
        
    }
    
    
    function RetrieveReSale(uint256[] memory resaleID,uint256[] memory TokenID) external{
        require(resaleID.length == TokenID.length,"GeoTokens: Parameter length mismatch");
        uint256 length = TokenID.length;
        uint256 i;
        for(i=0;i<length;i++){
            require(ResaleTokens[resaleID[i]].tokenID == TokenID[i], "GeoTokens: Token ID mismatch");
            require(block.timestamp > ResaleTokens[resaleID[i]].resaleTime, "GeoTokens: Auction has not ended yet");
        }
        for(i=0;i<length;i++){
            salesBalance[ownerOf(TokenID[i])] += ResaleTokens[resaleID[i]].highestBid;
            address previousOwner = ownerOf(TokenID[i]);
            safeTransferFrom(previousOwner,ResaleTokens[resaleID[i]].bidderAddress,TokenID[i]);
            emit ResaleRetrieve(previousOwner,ResaleTokens[resaleID[i]].bidderAddress,resaleID[i],TokenID[i]);
            delete ResaleTokens[resaleID[i]];
            metaData[TokenID[i]].status = 0;
        }
        
    }
    
    function StopResale(uint256 resaleID,uint256 TokenID) external{
        require(ownerOf(TokenID) == msg.sender,"GeoTokens: User is not the owner of this NFT");
        require(ResaleTokens[resaleID].tokenID == TokenID, "GeoTokens: Token ID mismatch");
        require(metaData[TokenID].status == 3,"GeoTokens: NFT is not for resale");
        if(ResaleTokens[resaleID].bidderAddress != address(0)){
            payable(ResaleTokens[resaleID].bidderAddress).transfer(ResaleTokens[resaleID].highestBid);
        }
        metaData[TokenID].status = 0;
        delete ResaleTokens[resaleID];
        emit ResaleRemoved(resaleID,TokenID);
    }
    
    function ExtendResale(uint256 resaleID,uint256 TokenID,uint256 newTime) external{
        require(ownerOf(TokenID) == msg.sender,"GeoTokens: User is not the owner of this NFT");
        require(ResaleTokens[resaleID].tokenID == TokenID, "GeoTokens: Token ID mismatch");
        require(ResaleTokens[resaleID].resaleTime < newTime,"GeoTokens: Can't reduce Auction time");
        require(metaData[TokenID].status == 3,"GeoTokens: NFT is not for resale");
        ResaleTokens[resaleID].resaleTime = newTime;
        emit ResaleCreation(TokenID,resaleID,ResaleTokens[resaleID],block.timestamp);   
    }
}
