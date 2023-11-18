const { task } = require("hardhat/config");

require("dotenv").config();

require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("@openzeppelin/hardhat-upgrades");
require("hardhat-contract-sizer");

task("deploy", "Deploy contract").setAction(async () => {
  const deploy = require("./tasks/deploy");
  await deploy();
});

task("upgrade", "Upgrade contract").setAction(async () => {
  const upgrade = require("./tasks/upgrade");
  await upgrade();
});

task("execute", "Execute contract").setAction(async () => {
  const execute = require("./tasks/execute");
  await execute();
});

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "gnosis",
  solidity: {
    version: "0.8.21",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
  networks: {
    gnosis: {
      chainId: 100,
      url: "https://rpc.ankr.com/gnosis",
      accounts: [process.env.PRIVATE_KEY],
      gasMultiplier: 4,
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: {
      gnosis: process.env.GNOSIS_API_KEY,
    },
    customChains: [
      {
        network: "gnosis",
        chainId: 100,
        urls: {
          apiURL: "https://api.gnosisscan.io/api",
          browserURL: "https://gnosisscan.io",
        },
      },
    ],
  },
  contractSizer: {
    alphaSort: false,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    only: [],
  },
};
