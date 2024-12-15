require('dotenv').config();
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require('hardhat-deploy');
require("@nomicfoundation/hardhat-chai-matchers");

const {
  PRIVATE_KEY,
  ALCHEMY_API_KEY_MAINNET,
  ALCHEMY_API_KEY_GOERLI,
  ALCHEMY_API_KEY_POLYGON,
  ALCHEMY_API_KEY_MUMBAI,
  ALCHEMY_API_KEY_SEPOLIA,
  ETHERSCAN_API_KEY,
  POLYGONSCAN_API_KEY,
  BASESCAN_API_KEY,
  
} = process.env;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.24", // 新しく追加
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          },
          viaIR: true  // IRモードを有効化
        }
      },
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
      {
        version: "0.8.1",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
      {
        version: "0.8.0",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }
    ]
  },

  networks: {
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    goerli: {
      url: `https://eth-goerli.alchemyapi.io/v2/${ALCHEMY_API_KEY_GOERLI}`,
      accounts: [PRIVATE_KEY]
    },
    mainnet: {
      url: `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_API_KEY_MAINNET}`,
      accounts: [PRIVATE_KEY]
    },
    polygon: {
      url: `https://polygon-mainnet.g.alchemyapi.io/v2/${ALCHEMY_API_KEY_POLYGON}`,
      accounts: [PRIVATE_KEY]
    },
    mumbai: {
      url: `https://polygon-mumbai.alchemyapi.io/v2/${ALCHEMY_API_KEY_MUMBAI}`,
      accounts: [PRIVATE_KEY]
    },
    sepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${ALCHEMY_API_KEY_SEPOLIA}`,
      accounts: [PRIVATE_KEY]
    },
    zKatana: {
      url: "https://aster-api.zkatana.net",
      accounts: [PRIVATE_KEY]
    },
    base: {
      url: 'https://mainnet.base.org',
      accounts: [PRIVATE_KEY],
      gasPrice: 1000000000,
    },
    'base-sepolia': {
      url: 'https://sepolia.base.org',
      accounts: [PRIVATE_KEY],
      gasPrice: 1000000000,
    }
  },

  etherscan: {
    apiKey: {
      mainnet: ETHERSCAN_API_KEY,
      polygon: POLYGONSCAN_API_KEY,
      goerli: ETHERSCAN_API_KEY,
      sepolia: ETHERSCAN_API_KEY,
      base: BASESCAN_API_KEY,
      'base-goerli': BASESCAN_API_KEY,
      'base-sepolia': BASESCAN_API_KEY  // Base Sepolia用のAPIキーを追加

    },
    customChains: [
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org"
        }
      },
      {
        network: "base-goerli",
        chainId: 84531,
        urls: {
          apiURL: "https://api-goerli.basescan.org/api",
          browserURL: "https://goerli.basescan.org"
        }
      },
      {
        network: "base-sepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org"
        }
      }
    ]
  }
};
