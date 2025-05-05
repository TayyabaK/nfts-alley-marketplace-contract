require('@nomicfoundation/hardhat-toolbox');
require('@openzeppelin/hardhat-upgrades');
require('@nomicfoundation/hardhat-verify');
require('@openzeppelin/hardhat-upgrades');
require('dotenv').config();

const PRIVATE_KEY = process.env.PRIVATE_KEY;
module.exports = {
  networks: {
    baseSepolia: {
      chainId: 84532,
      url: 'https://sepolia.base.org',
      accounts: [`0x${PRIVATE_KEY}`],
      timeout: 300_000, // 5 minutes
    },
    holesky: {
      chainId: 17000,
      url: 'https://holesky.drpc.org',
      accounts: [`0x${PRIVATE_KEY}`],
    },
    sepolia: {
      chainId: 11155111,
      url: 'https://sepolia.drpc.org',
      accounts: [`0x${PRIVATE_KEY}`],
    },
    hardhat: {
      allowUnlimitedContractSize: true,
    },
  },
  etherscan: {
    apiKey: {
      // baseSepolia: '25M5QI5HSPF4CQ5E5Y3UVSRUVWSYKT261R',
      sepolia: '9K1QHBE9TJZEWCTA2CAC3YMEXGIRXKD2RK',
      // holesky: 'NIICVA1QW91C8MK9APDPEX29PHEFQHREXF',
    },
  },
  solidity: {
    compilers: [
      {
        version: '0.8.20',
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000,
          },
          viaIR: true,
        },
      },
      {
        version: '0.8.26',
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000,
          },
          viaIR: true,
        },
      },
      {
        version: '0.8.17',
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000,
          },
          viaIR: true,
        },
      },
      {
        version: '0.8.4',
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000,
          },
          viaIR: true,
        },
      },
    ],
    settings: {
      viaIR: true,
    },

    allowUnlimitedContractSize: true,
  },
};
