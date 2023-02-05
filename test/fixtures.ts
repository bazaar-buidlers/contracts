import { ethers, upgrades } from 'hardhat';

export async function deployEscrow() {
  const Token = await ethers.getContractFactory('TestERC20');
  const token = await Token.deploy();

  const Escrow = await ethers.getContractFactory('Escrow');
  const escrow = await Escrow.deploy();
  
  return { token, escrow };
}

export async function deployBazaar() {
  const { token, escrow } = await deployEscrow();

  const Bazaar = await ethers.getContractFactory('Bazaar');
  const bazaar = await upgrades.deployProxy(Bazaar, [300, escrow.address]);

  await escrow.transferOwnership(bazaar.address);

  return { token, escrow, bazaar };
}