import { ethers } from "hardhat";

async function main() {
  const Store = await ethers.getContractFactory("Store");
  const store = await Store.deploy();
  await store.deployed();
  console.log(`Store deployed to ${store.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
