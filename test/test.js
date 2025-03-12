// import { expect } from "chai";
const { parseEther, formatEther, parseUnits } = require("ethers");
const { ethers, upgrades } = require("hardhat");
const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

const setUpContracts = async () => {
  const [owner, addr1, addr2] = await ethers.getSigners();

  const ERC721Token = await ethers.deployContract("Token721", [owner]);
  const ERC1155Token = await ethers.deployContract("ERC1155Token", [
    "zule",
    "ss",
    100,
    owner,
    100,
  ]);

  const Market = await ethers.deployContract("NFTMarket", [owner, 100]);
  return { ERC721Token, ERC1155Token, Market, owner, addr1, addr2 };
};

describe("Marketplace", function () {
  async function deployFixtures() {
    const data = await setUpContracts();
    return data;
  }

  describe("ERC1155 and ERC1155 listing, and puchase", function () {
    it("list item from owner", async function () {
      //   const { factoryContract, owner, Token, addr1, addr2 } =
      const { ERC721Token, ERC1155Token, Market, owner, addr1, addr2 } =
        await loadFixture(deployFixtures);
      const token721Address = await ERC721Token.getAddress();
      const token1155Address = await ERC1155Token.getAddress();
      const marketAddress = await Market.getAddress();
      //mint token 721 and 1155
      await ERC721Token.connect(owner).safeMint(owner,1, "ss");
      await ERC1155Token.connect(owner).mintFromPlatform(owner, 1, 1, "0x", "ss");

      //approval to marketplace token 721 and 1155
      await ERC721Token.connect(owner).setApprovalForAll(marketAddress, true);
      await ERC1155Token.connect(owner).setApprovalForAll(marketAddress, true);
      //listing on  marketplace token 721 and 1155
      await Market.connect(owner).createMarketItem(token721Address, 1, 1);
      // await Market.connect(owner).createMarketItem(token1155Address, 1, 1);
      // get listed items
      // const item1 = await Market.connect(owner).getMarketItemsByContractTokenId(
      //   token721Address,
      //   1
      // );
      // const item2 = await Market.connect(owner).getMarketItemsByContractTokenId(
      //   token1155Address,
      //   1
      // );

      // console.log("item1", item1);
      // console.log("item2", item2);
      await Market.connect(addr1).createMarketSale( 1, {
        value: parseEther("0.2")
    });
      
      // console.log("item1", item1);
      // console.log("item2", item2);

    });

    // it("purchase 1155", async function () {

    // });
    // it("purchase 721", async function () {

    // });
  });
});
