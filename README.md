# geo-spatia-contracts
## Features

#### Struct Based Storage 
Geo NFTs have their metadata stored on chain as a struct which stores the name, location, price, sales status and layer number for the NFT and can easily be expanded to store IPFS cid as well.
``` 
  struct tokenInfo{
        string name;
        string location;
        uint8 status; 
        uint256 price;
        uint16 layer;
    } 
```
    
#### Layer  
NFTs have a attribute which can be individually locked or unlocked allowing layer based release of NFTs. Admin is able to manually enable or disable the sales for NFT in a  layer.
```
function changeLayerLock(uint16 layerNumber,bool status) external onlyApprovedOrOwner(msg.sender)
```
#### Unique Metadata 
Each metadata can only correspond to 1 NFT making each NFT unique and only admin or approved addresses can add these.
```
function CreateNew(tokenInfo[] memory MetaData,string[] memory svg,uint256[] memory DaysLater) external onlyApprovedOrOwner(msg.sender)
```
#### Primary Sales
Initial NFT sales have a bidding mechanism where users can bid and with every new highest bidder, previous highest bidder gets their staked amount back. 
```
function Bid(uint256 tokenID) external payable
```
After the auction is done users are able to retrieve their NFT at which point the NFT is actually first minted leaving the burden on gas cost on the user and not the contract owner.
```
function RetrieveNFT(uint256[] memory tokenID) external
```
#### Sale Options
Admin or approved can change the base price of the NFT at any point, this only changes the base prices and if it lower than original doesn't affect the auction if bidding has already started. If it is higher than original, new bidders will be compelled to start from maximum(previous bid, base price)
```
function SetPrice(uint256 tokenID,uint256 _price) external onlyApprovedOrOwner(msg.sender)
```
Admin or approved can change the Auction time as long the NFT has not already be retrieved.
```
function changeSaleTime(uint256 tokenID,uint256 newDaysLater) external onlyApprovedOrOwner(msg.sender)
```

#### Resale  
Owner of the can put it up for resale at their own price and auction deadline. At the same time they are doing set approve for all on the contract owner.
```
function putTokenForResale(uint256 price,uint256 TokenID,uint256 daysAfter) external
```
After which other users can bid for the NFT in the same way.
```
function bidResale(uint256 resaleID,uint256 TokenID) external payable
```
When the auction ends, the contract owner (or possibly a designated operator address) can transfer the NFTs from seller to the buyer.
```
function RetrieveReSale(uint256[] memory resaleID,uint256[] memory TokenID) external
```
Resellers have the ability to stop the auction at any point as long as they carry the ownership and can refund the highest bidder. 
```
function StopResale(uint256 resaleID,uint256 TokenID) external
```
They also have the option to extend the auction time
```
function ExtendResale(uint256 resaleID,uint256 TokenID,uint256 newTime) external
```

