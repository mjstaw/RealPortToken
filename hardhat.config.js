require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("hardhat-contract-sizer");

const runOnCompile = process.env.HARDHAT_TASK_NAME === "compile";

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile, // only true if the task is compile
    strict: false
  },
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC,
      accounts: [process.env.PRIVATE_KEY]
    },
    localhost: {
      url: "http://127.0.0.1:8545"
    }
  }
};
