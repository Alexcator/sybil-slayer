const hre = require("hardhat");
const { ethers, upgrades } = hre;

module.exports = async function () {
  const contractName = `AntiSybil`;
  const PROXY_ADDRESS = ``;

  await hre.run("compile");

  // We get the contract to deploy
  const contractFactory = await ethers.getContractFactory(contractName);

  const contract = await upgrades.upgradeProxy(PROXY_ADDRESS, contractFactory, {
    gasLimit: 110000000,
    gasPrice: 110000000000000,
    timeout: 600000,
    pollingInterval: 5000
  });

  console.log(`Tx hash`, contract.deployTransaction.hash);

  await contract.deployed();
  console.log(`UpgradeProxy successful! Contract Address:`, contract.address);
  console.log(`To verify AntiSybil: npx hardhat verify --network ${hre.network.name} ${contract.address}`);
};
