import { ethers } from 'hardhat';
import { BigNumber } from 'ethers';

const items = [
  {
    id: 0,
    limit: 100,
    config: 0,
    tokenURI: 'ipfs://bafkreicp7goi4b5n6ucuvlchb3qptlot3di77sbdhtrlapp64twku43xhu',
  },
  {
    id: 1,
    limit: 200,
    config: (1 << 0), // paused
    tokenURI: 'ipfs://bafkreicp7goi4b5n6ucuvlchb3qptlot3di77sbdhtrlapp64twku43xhu',
  },
  {
    id: 2,
    limit: 300,
    config: (1 << 1), // free
    tokenURI: 'ipfs://bafkreicp7goi4b5n6ucuvlchb3qptlot3di77sbdhtrlapp64twku43xhu',
  },
  {
    id: 3,
    limit: 400,
    config: (1 << 2), // soulbound
    tokenURI: 'ipfs://bafkreicp7goi4b5n6ucuvlchb3qptlot3di77sbdhtrlapp64twku43xhu',
  },
  {
    id: 4,
    limit: 500,
    config: (1 << 3), // unique
    tokenURI: 'ipfs://bafkreicp7goi4b5n6ucuvlchb3qptlot3di77sbdhtrlapp64twku43xhu',
  },
];

export async function deploy() {
  const [deployer] = await ethers.getSigners();
  const owner = await deployer.getAddress();

  const feeNumerator = 1000;
  const feeDenominator = 10000;

  const TestToken = await ethers.getContractFactory('TestToken');
  const testToken = await TestToken.deploy();

  const Bazaar = await ethers.getContractFactory('Bazaar');
  const bazaar = await Bazaar.deploy(feeNumerator, feeDenominator);

  return { bazaar, testToken, owner, feeNumerator, feeDenominator };
}

export async function list() {
  const { bazaar, ...rest } = await deploy();

  for (const item of items) {
    await bazaar.list(item.limit, item.config, item.tokenURI);
  }

  return { bazaar, items, ...rest };
}

export async function appraise() {
  const { bazaar, testToken, ...rest } = await list();
  const erc20s = [ethers.constants.AddressZero, testToken.address];

  for (const item of items) {
    const price1 = BigNumber.from(ethers.utils.randomBytes(4));
    const price2 = BigNumber.from(ethers.utils.randomBytes(4));
    await bazaar.appraise(item.id, erc20s, [price1, price2]);
  }

  return { bazaar, testToken, ...rest };
}