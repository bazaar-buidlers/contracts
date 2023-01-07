import { HardhatUserConfig } from 'hardhat/config';
import 'hardhat-gas-reporter';
import '@nomicfoundation/hardhat-chai-matchers';
import '@nomiclabs/hardhat-ethers';

const config: HardhatUserConfig = {
  solidity: '0.8.17',
  gasReporter: {
    currency: 'USD'
  },
};

export default config;
