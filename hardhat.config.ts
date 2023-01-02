import { HardhatUserConfig } from 'hardhat/config';
import 'hardhat-gas-reporter';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';

const config: HardhatUserConfig = {
  solidity: '0.8.17',
  gasReporter: {
    currency: 'USD'
  },
};

export default config;
