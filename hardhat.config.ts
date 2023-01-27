import { HardhatUserConfig } from 'hardhat/config';
import * as dotenv from 'dotenv'

import 'hardhat-gas-reporter';
import '@nomicfoundation/hardhat-chai-matchers';
import '@nomiclabs/hardhat-ethers';
import '@openzeppelin/hardhat-upgrades';

dotenv.config();

const alchemyApiKey = process.env.ALCHEMY_API_KEY;
const privateKey = process.env.PRIVATE_KEY;

const networkConfig = (name: string) => ({
  url: `https://${name}.g.alchemy.com/v2/${alchemyApiKey}`,
  accounts: (privateKey ? [privateKey] : []),
});

const config: HardhatUserConfig = {
  solidity: '0.8.17',
  settings: {
    optimizer: {
      enabled: true,
      runs: 1000,
    },
  },
  gasReporter: {
    currency: 'USD'
  },
  networks: {
    'arbitrum': networkConfig('arbitrum'),
    'arbitrum-goerli': networkConfig('arb-goerli'),
  },
};

export default config;
