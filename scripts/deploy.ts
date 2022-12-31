import { ethers } from "hardhat";

async function main() {
  const Bazaar = await ethers.getContractFactory("Bazaar");
  const bazaar = await Bazaar.deploy();
  
  await bazaar.deployed();
  console.log(`Bazaar deployed to ${bazaar.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
