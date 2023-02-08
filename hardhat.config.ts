import { HardhatUserConfig } from 'hardhat/config';
import * as dotenv from 'dotenv'

import 'hardhat-gas-reporter';
import 'hardhat-contract-sizer';
import '@nomicfoundation/hardhat-chai-matchers';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
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
  contractSizer: {
    runOnCompile: true,
  },
  gasReporter: {
    currency: 'USD'
  },
  etherscan: {
    apiKey: {
      arbitrumGoerli: process.env.ARBISCAN_API_KEY as string,
      arbitrumOne: process.env.ARBISCAN_API_KEY as string,
    },
  },
  networks: {
    'arbitrum': networkConfig('arbitrum'),
    'arbitrum-goerli': networkConfig('arb-goerli'),
  },
};

export default config;
