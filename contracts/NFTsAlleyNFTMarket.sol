// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./IMarket.sol";

contract NFTsAlleyNFTMarket is
    IMarket,
    Initializable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    IERC1155Receiver,
    IERC721Receiver,
    UUPSUpgradeable
{
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 private itemIds;
    uint256 private itemsSold;
    uint256 public marketplaceFeeBp;
    address public feeCollector;
    address public multiSigWallet;

    bytes4 private constant INTERFACE_ID_ERC2981 = 0x2a55205a;

    mapping(address => address) public royalityAddresses;
    mapping(uint256 => MarketItem) public idToMarketItem;
    mapping(uint256 => mapping(address => OfferData)) public offers;
    mapping(address => mapping(uint256 => EnumerableSet.UintSet))
        private nftContractTokenIdToItemId;

    modifier onlyMultiSig() {
        require(msg.sender == multiSigWallet, "Not authorized");
        _;
    }

    function initialize(
        address feeCollectorWallet,
        uint256 marketplaceFeeBasisPoint
    ) public initializer {
        require(feeCollectorWallet != address(0), "Invalid address");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        feeCollector = feeCollectorWallet;
        marketplaceFeeBp = marketplaceFeeBasisPoint;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    fallback() external payable {
        emit FallbackReceived(msg.sender, msg.value);
    }

    receive() external payable {
        emit FallbackReceived(msg.sender, msg.value);
    }

    modifier checkInterfaceSupport(address nftContract) {
        require(
            IERC165(nftContract).supportsInterface(type(IERC721).interfaceId) ||
                IERC165(nftContract).supportsInterface(
                    type(IERC1155).interfaceId
                ),
            "Invalid NFT contract"
        );

        _;
    }

    function pause() external onlyMultiSig {
        _pause();
    }

    function unpause() external onlyMultiSig {
        _unpause();
    }

    function isERC721(address nftContract) internal view returns (bool) {
        return
            IERC165(nftContract).supportsInterface(type(IERC721).interfaceId);
    }

    function isERC1155(address nftContract) internal view returns (bool) {
        return
            IERC165(nftContract).supportsInterface(type(IERC1155).interfaceId);
    }

    function transferNft(
        address from,
        address to,
        uint256 tokenId,
        address nftContract
    ) internal {
        if (isERC1155(nftContract)) {
            IERC1155(nftContract).safeTransferFrom(from, to, tokenId, 1, "");
        } else {
            if (isERC721(nftContract)) {
                IERC721(nftContract).safeTransferFrom(from, to, tokenId);
            }
        }
    }

    function _checkRoyalties(
        address contract_address
    ) internal view returns (bool) {
        bool success = IERC2981(contract_address).supportsInterface(
            INTERFACE_ID_ERC2981
        );
        return success;
    }

    function _deduceRoyalties(
        address nftContract,
        uint256 tokenId,
        uint256 grossSaleValue
    ) internal returns (uint256) {
        // Get amount of royalties to pays and recipient
        (address royaltiesReceiver, uint256 royaltiesAmount) = IERC2981(
            nftContract
        ).royaltyInfo(tokenId, grossSaleValue);

        require(royaltiesReceiver != address(0), "Invalid royalties receiver");
        require(royaltiesAmount <= grossSaleValue, "Invalid royalties amount");

        // Deduce royalties from sale value
        uint256 netSaleValue = grossSaleValue - royaltiesAmount;
        // Transfer royalties to rightholder if not zero
        if (royaltiesAmount > 0) {
            if (royalityAddresses[nftContract] != address(0)) {
                if (
                    !safeTransfer(
                        payable(royalityAddresses[nftContract]),
                        royaltiesAmount
                    )
                ) {
                    emit TransferFailed(
                        royalityAddresses[nftContract],
                        royaltiesAmount
                    );
                }
            }
        } else {
            if (!safeTransfer(payable(royaltiesReceiver), royaltiesAmount)) {
                emit TransferFailed(royaltiesReceiver, royaltiesAmount);
            }
        }

        // Broadcast royalties payment
        emit RoyaltiesPaid(tokenId, royaltiesAmount);
        return netSaleValue;
    }

    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        string memory nftJson
    ) external nonReentrant whenNotPaused checkInterfaceSupport(nftContract) {
        require(price > 0, "Price must be at least 1 wei");
        require(
            feeCollector != address(0),
            "Fee Collector address is not configured"
        );

        require(nftContract != address(0), "Invalid address");
        itemIds += 1;
        uint256 itemId = itemIds;

        idToMarketItem[itemId] = MarketItem(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            price,
            1
        );

        nftContractTokenIdToItemId[nftContract][tokenId].add(itemId);

        transferNft(msg.sender, address(this), tokenId, nftContract);

        emit MarketItemCreated(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            address(0),
            price,
            false,
            block.timestamp,
            nftJson
        );
    }

    function makeOffer(
        uint256 itemId
    ) external payable nonReentrant whenNotPaused {
        MarketItem memory item = idToMarketItem[itemId];

        require(
            msg.value < idToMarketItem[itemId].price,
            "Offer value must not exceed item price"
        );

        require(item.seller != address(0), "makeOffer: item does not exist");

        require(item.status == 1, "makeOffer: item is not listed");
        require(msg.value > 0, "makeOffer: insufficient amount");
        require(
            msg.sender != item.seller,
            "makeOffer: seller cannot make offer"
        );
        require(
            offers[itemId][msg.sender].offerPrice == 0,
            "An offer already exist"
        );

        offers[itemId][msg.sender] = OfferData(
            msg.sender,
            item.nftContract,
            itemId,
            item.tokenId,
            msg.value,
            block.timestamp,
            1 // Active
        );

        emit OfferCreated(
            itemId,
            msg.sender,
            msg.value,
            item.nftContract,
            item.tokenId,
            block.timestamp
        );
    }

    function cancelOffer(uint256 itemId) external nonReentrant {
        OfferData memory offer = offers[itemId][msg.sender];
        require(
            msg.sender == offer.offeror,
            "cancelOffer: not offeror Address"
        );
        require(offer.status != 2, "cancelOffer: offer already accepted");

        require(
            address(this).balance >= offer.offerPrice,
            "Insufficient contract balance for refund"
        );
        (bool sentToOfferor, ) = payable(msg.sender).call{
            value: offer.offerPrice
        }("");
        require(sentToOfferor, "Transfer to Offeror collector failed");

        offers[itemId][msg.sender].status = 3; // Mark as withdrawn
        offers[itemId][msg.sender].offerPrice = 0;
        emit OfferCancelled(
            itemId,
            offer.offeror,
            offer.offerPrice,
            idToMarketItem[itemId].nftContract,
            idToMarketItem[itemId].tokenId
        );
    }

    function acceptOffer(
        uint256 itemId,
        address offeror
    ) public nonReentrant whenNotPaused {
        require(offeror != address(0), "Invalid address");
        OfferData memory offer = offers[itemId][offeror];
        require(
            idToMarketItem[itemId].status == 1,
            "Market item is not listed or already sold"
        );
        require(
            idToMarketItem[itemId].seller == msg.sender,
            "acceptOffer: only seller can accept"
        );
        require(offer.status == 1, "acceptOffer: offer is not active");
        require(
            address(this).balance >= offer.offerPrice,
            "Insufficient contract balance for refund"
        );
        uint256 elapsedTime = block.timestamp -
            offers[itemId][offeror].createdAt;
        require(elapsedTime <= 31536000, "acceptOffer: offer is not active");
        uint256 platformFee = (offer.offerPrice * marketplaceFeeBp) / 10000;
        uint256 saleValue = offer.offerPrice - platformFee;

        if (_checkRoyalties(idToMarketItem[itemId].nftContract)) {
            saleValue = _deduceRoyalties(
                idToMarketItem[itemId].nftContract,
                idToMarketItem[itemId].tokenId,
                saleValue
            );
        }

        if (!safeTransfer(payable(feeCollector), platformFee)) {
            emit TransferFailed(feeCollector, platformFee);
        }
        if (!safeTransfer(payable(msg.sender), saleValue)) {
            emit TransferFailed((msg.sender), saleValue);
        }

        transferNft(
            address(this),
            offer.offeror,
            idToMarketItem[itemId].tokenId,
            idToMarketItem[itemId].nftContract
        );
        nftContractTokenIdToItemId[idToMarketItem[itemId].nftContract][
            idToMarketItem[itemId].tokenId
        ].remove(itemId);
        idToMarketItem[itemId].owner = payable(offer.offeror);
        idToMarketItem[itemId].seller = payable(address(0));
        idToMarketItem[itemId].status = 2;
        offers[itemId][offeror].status = 2;

        itemsSold += 1;

        emit OfferAccepted(
            msg.sender,
            itemId,
            offeror,
            offer.offerPrice,
            idToMarketItem[itemId].nftContract,
            idToMarketItem[itemId].tokenId
        );
    }

    function releaseSale(uint256 itemId) external nonReentrant {
        MarketItem memory item = idToMarketItem[itemId];
        require(item.status == 1, "releaseSale: Item is not listed");
        require(item.seller == msg.sender, "releaseSale: not the seller");
        transferNft(address(this), msg.sender, item.tokenId, item.nftContract);

        idToMarketItem[itemId].owner = payable(msg.sender);
        idToMarketItem[itemId].status = 3; // Removed
        idToMarketItem[itemId].seller = payable(address(0));
        idToMarketItem[itemId].price = 0;
        nftContractTokenIdToItemId[idToMarketItem[itemId].nftContract][
            idToMarketItem[itemId].tokenId
        ].remove(itemId);
        emit MarketItemReleased(
            itemId,
            item.nftContract,
            item.tokenId,
            msg.sender
        );
    }

    function createMarketSale(
        uint256 itemId
    ) external payable nonReentrant whenNotPaused {
        uint256 price = idToMarketItem[itemId].price;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        address nftContract = idToMarketItem[itemId].nftContract;

        require(
            idToMarketItem[itemId].status == 1,
            "Market item is not listed or already sold"
        );
        require(msg.value >= price, "createMarketSale: insufficient payment");

        uint256 platformFee = (msg.value * marketplaceFeeBp) / 10000;
        uint256 saleValue = msg.value - platformFee;
        idToMarketItem[itemId].owner = payable(msg.sender);
        idToMarketItem[itemId].status = 2;
        idToMarketItem[itemId].seller = payable(address(0));
        nftContractTokenIdToItemId[idToMarketItem[itemId].nftContract][
            idToMarketItem[itemId].tokenId
        ].remove(itemId);

        itemsSold += 1;
        if (_checkRoyalties(idToMarketItem[itemId].nftContract)) {
            saleValue = _deduceRoyalties(nftContract, tokenId, saleValue);
        }
        if (!safeTransfer(payable(feeCollector), platformFee)) {
            emit TransferFailed((feeCollector), platformFee);
        }
        if (!safeTransfer(idToMarketItem[itemId].seller, saleValue)) {
            emit TransferFailed(idToMarketItem[itemId].seller, saleValue);
        }
        transferNft(address(this), msg.sender, tokenId, nftContract);

        emit MarketItemSale(itemId, nftContract, tokenId, msg.sender, price);
    }

    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = itemIds;
        uint256 unsoldItemCount = itemIds - itemsSold;
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(0)) {
                uint256 currentId = i + 1;
                items[currentIndex] = idToMarketItem[currentId];
                currentIndex += 1;
            }
        }
        return items;
    }

    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = itemIds;
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                items[currentIndex] = idToMarketItem[currentId];
                currentIndex += 1;
            }
        }
        return items;
    }

    function fetchItemsCreated() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = itemIds;
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                items[currentIndex] = idToMarketItem[currentId];
                currentIndex += 1;
            }
        }
        return items;
    }

    function fetchMyOffer(
        uint256 itemId
    ) external view returns (OfferData memory) {
        OfferData memory items = offers[itemId][msg.sender];
        return items;
    }

    function setSaleFeeBpAndWallet(
        uint256 saleFee,
        address feeCollector
    ) external onlyMultiSig {
        require(feeCollector != address(0), "Invalid fee collector address");
        require(saleFee <= 2500, "Too much sale fee");
        marketplaceFeeBp = saleFee;

        feeCollector = feeCollector;
        emit FeeUpdated(saleFee, feeCollector);
    }

    function setRoyalityAddresses(
        address royalityAddress,
        address nftContract
    ) external onlyMultiSig {
        royalityAddresses[nftContract] = royalityAddress;
    }

    function setMultiSigWallet(address multiSigWallet) external onlyOwner {
        require(multiSigWallet != address(0), "Invalid address");
        multiSigWallet = multiSigWallet;
        emit MultiSigWalletUpdated(multiSigWallet);
    }

    function withdrawETH() external onlyMultiSig nonReentrant {
        require(address(this).balance > 0, "No balance to withdraw");
        payable(multiSigWallet).transfer(address(this).balance);
    }

    function fetchMyAllOffers() external view returns (OfferData[] memory) {
        uint256 totalItemCount = itemIds;
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        // First loop to count the total number of active offers
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (offers[i + 1][msg.sender].status == 1) {
                itemCount++;
            }
        }

        // Create a memory array with the exact size
        OfferData[] memory items = new OfferData[](itemCount);

        // Second loop to populate the array with active offers
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (offers[i + 1][msg.sender].status == 1) {
                items[currentIndex] = offers[i + 1][msg.sender];
                currentIndex++;
            }
        }

        return items;
    }

    function getItemIdsFromContractTokenId(
        address nftContract,
        uint256 tokenId
    ) public view returns (uint256[] memory) {
        return nftContractTokenIdToItemId[nftContract][tokenId].values();
    }

    function getMarketItemsByContractTokenId(
        address nftContract,
        uint256 tokenId
    ) public view returns (MarketItem[] memory) {
        uint256 length = nftContractTokenIdToItemId[nftContract][tokenId]
            .length();
        MarketItem[] memory marketItemsArray = new MarketItem[](length);

        for (uint256 i = 0; i < length; i++) {
            marketItemsArray[i] = idToMarketItem[i + 1];
        }

        return marketItemsArray;
    }

    // Required override for ERC1155Receiver
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external view virtual override returns (bool) {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    function safeTransfer(
        address payable recipient,
        uint256 amount
    ) internal returns (bool) {
        (bool success, ) = recipient.call{value: amount}("");
        return success;
    }

    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external override {}
}
