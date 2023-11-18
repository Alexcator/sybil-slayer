const hre = require("hardhat");

require("@openzeppelin/hardhat-upgrades");

async function main() {
  const contractName = `AntiSybil`;
  const props = [18];

  await hre.run("compile");

  // We get the contract to deploy
  const contractFactory = await hre.ethers.getContractFactory(contractName);
  const contract = await hre.upgrades.deployProxy(contractFactory, [...props], {
    initializer: "initialize",
    gasLimit: 3000000,
    gasPrice: 4000000000,
    timeout: 600000,
    pollingInterval: 5000,
  });

  console.log(`AntiSybil tx hash`, contract.deployTransaction.hash);

  await contract.deployed();
  const tx = await contract.deployTransaction.wait();

  console.log(`Deployment Gas Used: ${tx.cumulativeGasUsed.toString()}`);

  await hre.run("verify:verify", {
    address: contract.address,
    constructorArguments: [],
  });

  const proxyAdmin = (await hre.upgrades.admin.getInstance()).address;
  console.log(`ProxyAdmin: ${proxyAdmin}`);
  console.log(
    `Deployment "${contractName}" successful! Contract Address:`,
    contract.address
  );
  console.log(
    `To verify AntiSybil: npx hardhat verify --network ${hre.network.name} ${contract.address}`
  );
}

module.exports = main;
