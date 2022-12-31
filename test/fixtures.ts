import { ethers } from 'hardhat';

export async function deploy() {
  const [deployer] = await ethers.getSigners();
  const owner = await deployer.getAddress();

  const feeNumerator = 1000;
  const feeDenominator = 10000;

  const Bazaar = await ethers.getContractFactory('Bazaar');
  const bazaar = await Bazaar.deploy(feeNumerator, feeDenominator);

  return { bazaar, owner, feeNumerator, feeDenominator };
}

export async function list() {
  const { bazaar, ...rest } = await deploy();

  const id = 0;
  const limit = ethers.constants.MaxUint256;
  const config = 0;
  const tokenURI = 'ipfs://bafkreicp7goi4b5n6ucuvlchb3qptlot3di77sbdhtrlapp64twku43xhu';
  
  await bazaar.list(limit, config, tokenURI);
  
  return { bazaar, id, limit, config, tokenURI, ...rest };
}