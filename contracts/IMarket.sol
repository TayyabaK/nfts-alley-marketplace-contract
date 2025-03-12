// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IMarket {
    struct OfferData {
        address offeror;
        address contractAddress;
        uint256 itemId;
        uint256 tokenId;
        uint256 offerPrice;
        uint256 createdAt; //offer stay valid for 1 year
        uint256 status; // 1 = active, 2 = accepted, 3 = cancelled
    }

    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        uint256 status; // 1 = listed, 2 = sold , 3 = removed
    }

    event FallbackReceived(address indexed sender, uint256 value);

    event MarketItemSale(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address owner,
        uint256 price
    );

    event MarketItemReleased(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller
    );
    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold,
        uint256 createdAt,        
        string nftJson
    );

    event RoyaltiesPaid(uint256 tokenId, uint256 value);

    event OfferCreated(
        uint256 nftID,
        address indexed offeror,
        uint256 amount,
        address nftContract,
        uint256 tokenId,
        uint256 createdAt
    );
    event OfferAccepted(
        address indexed owner,
        uint256 nftID,
        address indexed offeror,
        uint256 amount,
        address nftContract,
        uint256 tokenId
    );
    event OfferCancelled(
        uint256 nftID,
        address indexed offeror,
        uint256 amount,
        address nftContract,
        uint256 tokenId
    );
    event FeeUpdated(uint256 feeAmount, address indexed feeWallet);
    event TransferFailed(address royaltiesReceiver, uint256 royaltiesAmount);

    event MultiSigWalletUpdated(address multiSigWallet);

    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external;

    function makeOffer(uint256 itemId) external payable;

    function cancelOffer(uint256 itemId) external;

    function acceptOffer(uint256 itemId, address offeror) external;

    function releaseSale(uint256 itemId) external;

    function createMarketSale(uint256 itemId) external payable;

    function fetchMarketItems() external view returns (MarketItem[] memory);

    function fetchMyNFTs() external view returns (MarketItem[] memory);

    function fetchMyAllOffers() external view returns (OfferData[] memory);

    function fetchItemsCreated() external view returns (MarketItem[] memory);

    function fetchMyOffer(
        uint256 itemId
    ) external view returns (OfferData memory);

    function setSaleFeeBpAndWallet(
        uint256 _saleFee,
        address _feeCollector
    ) external;

    function setRoyalityAddresses(
        address _royalityAddress,
        address _nftContract
    ) external;

    function withdrawETH() external;
}
