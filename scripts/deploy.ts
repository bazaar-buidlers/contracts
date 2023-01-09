import { ethers } from 'hardhat';

async function main() {
  const Catalog = await ethers.getContractFactory('Catalog');
  const catalog = await Catalog.deploy();

  await catalog.deployed();
  console.log(`Catalog deployed to ${catalog.address}`);

  const Bazaar = await ethers.getContractFactory('Bazaar');
  const bazaar = await Bazaar.deploy(catalog.address, 300);
  
  await bazaar.deployed();
  console.log(`Bazaar deployed to ${bazaar.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
