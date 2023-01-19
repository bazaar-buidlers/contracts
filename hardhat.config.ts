import { HardhatUserConfig } from 'hardhat/config';
import 'hardhat-gas-reporter';
import '@nomicfoundation/hardhat-chai-matchers';
import '@nomiclabs/hardhat-ethers';
import '@openzeppelin/hardhat-upgrades';

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
};

export default config;
