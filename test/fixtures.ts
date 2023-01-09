import { ethers } from 'hardhat';

export async function deployEscrow() {
  const [deployer] = await ethers.getSigners();
  const owner = await deployer.getAddress();

  const TestToken = await ethers.getContractFactory('TestToken');
  const testToken = await TestToken.deploy();

  const Escrow = await ethers.getContractFactory('Escrow');
  const escrow = await Escrow.deploy();

  return { escrow, testToken };
}

export async function deployCatalog() {
  const [deployer] = await ethers.getSigners();
  const owner = await deployer.getAddress();

  const Catalog = await ethers.getContractFactory('Catalog');
  const catalog = await Catalog.deploy();

  return { catalog };
}
