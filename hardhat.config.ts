import '@nomicfoundation/hardhat-chai-matchers';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import '@openzeppelin/hardhat-upgrades';
import { HardhatUserConfig } from 'hardhat/config';
import 'hardhat-gas-reporter';
import 'hardhat-contract-sizer';
import 'solidity-coverage';
import * as dotenv from 'dotenv'

dotenv.config();

const alchemyApiKey = process.env.ALCHEMY_API_KEY;
const privateKey = process.env.PRIVATE_KEY;

const networkConfig = (name: string) => ({
  url: `https://${name}.g.alchemy.com/v2/${alchemyApiKey}`,
  accounts: (privateKey ? [privateKey] : []),
});

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.17',
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
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
    'arbitrum': networkConfig('arb-mainnet'),
    'arbitrum-goerli': networkConfig('arb-goerli'),
  },
};

export default config;
