import { ethers, upgrades } from 'hardhat';

async function main() {
  const Escrow = await ethers.getContractFactory('Escrow');
  const escrow = await Escrow.deploy();

  await escrow.deployed();
  console.log(`Escrow deployed to ${escrow.address}`);

  const Bazaar = await ethers.getContractFactory('Bazaar');
  const bazaar = await upgrades.deployProxy(Bazaar, [300, escrow.address]);

  await bazaar.deployed();
  console.log(`Bazaar deployed to ${bazaar.address}`);

  await escrow.transferOwnership(bazaar.address);
  console.log(`Escrow owner transferred to ${bazaar.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
