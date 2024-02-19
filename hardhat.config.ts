import * as dotenv from 'dotenv';
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
dotenv.config();

function getWallet(): Array<string> {
  return process.env.DEPLOYER_WALLET_PRIVATE_KEY !== undefined
    ? [process.env.DEPLOYER_WALLET_PRIVATE_KEY]
    : [];
}

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.9',
        settings: {
          optimizer: {
            enabled:
              (process.env.SOLIDITY_OPTIMIZER &&
                'true' === process.env.SOLIDITY_OPTIMIZER.toLowerCase()) ||
              false,
            runs:
              (process.env.SOLIDITY_OPTIMIZER_RUNS &&
                Boolean(parseInt(process.env.SOLIDITY_OPTIMIZER_RUNS)) &&
                parseInt(process.env.SOLIDITY_OPTIMIZER_RUNS)) ||
              200,
          },
          outputSelection: {
            '*': {
              '*': ['storageLayout'],
            },
          },
        },
      },

      {
        version: '0.8.19',
        settings: {
          optimizer: {
            enabled:
              (process.env.SOLIDITY_OPTIMIZER &&
                'true' === process.env.SOLIDITY_OPTIMIZER.toLowerCase()) ||
              false,
            runs:
              (process.env.SOLIDITY_OPTIMIZER_RUNS &&
                Boolean(parseInt(process.env.SOLIDITY_OPTIMIZER_RUNS)) &&
                parseInt(process.env.SOLIDITY_OPTIMIZER_RUNS)) ||
              200,
          },
          outputSelection: {
            '*': {
              '*': ['storageLayout'],
            },
          },
        },
      },

      {
        version: '0.8.20',
        settings: {
          optimizer: {
            enabled:
              (process.env.SOLIDITY_OPTIMIZER &&
                'true' === process.env.SOLIDITY_OPTIMIZER.toLowerCase()) ||
              false,
            runs:
              (process.env.SOLIDITY_OPTIMIZER_RUNS &&
                Boolean(parseInt(process.env.SOLIDITY_OPTIMIZER_RUNS)) &&
                parseInt(process.env.SOLIDITY_OPTIMIZER_RUNS)) ||
              200,
          },
          outputSelection: {
            '*': {
              '*': ['storageLayout'],
            },
          },
        },
      },
    ],
  },
  networks:{
    hardhat: {
      allowUnlimitedContractSize:
        (process.env.ALLOW_UNLIMITED_CONTRACT_SIZE &&
          'true' === process.env.ALLOW_UNLIMITED_CONTRACT_SIZE.toLowerCase()) ||
        false,
    },
    custom: {
      url: process.env.CUSTOM_NETWORK_URL || '',
      accounts: {
        count:
          (process.env.CUSTOM_NETWORK_ACCOUNTS_COUNT &&
            Boolean(parseInt(process.env.CUSTOM_NETWORK_ACCOUNTS_COUNT)) &&
            parseInt(process.env.CUSTOM_NETWORK_ACCOUNTS_COUNT)) ||
          0,
        mnemonic: process.env.CUSTOM_NETWORK_ACCOUNTS_MNEMONIC || '',
        path: process.env.CUSTOM_NETWORK_ACCOUNTS_PATH || '',
      },
    },
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || '',
      accounts: getWallet(),
    },
    arbitrum: {
      url: process.env.ARBITRUM_URL || '',
      accounts: getWallet(),
    },
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.ETHERSCAN_API_KEY || '',
      arbitrumOne: process.env.ARBITRUM_API_KEY || ''
    },
    
  },
};

export default config;
