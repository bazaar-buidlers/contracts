import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { constants, BigNumber } from 'ethers';
import { deployEscrow } from './fixtures';

describe('Escrow', function () {
  describe('deposit', function() {
    it('should work with native tokens', async function() {
      const { escrow } = await loadFixture(deployEscrow);

      const [owner] = await ethers.getSigners();
      const ownerAddress = await owner.getAddress();

      const value = BigNumber.from(1_000_000);
      const erc20 = constants.AddressZero;

      await escrow.deposit(ownerAddress, erc20, value, { value });
      expect(await escrow.depositsOf(ownerAddress, erc20)).to.equal(value);
    });

    it('should work with erc20 tokens', async function() {
      const { escrow, testToken } = await loadFixture(deployEscrow);

      const [owner] = await ethers.getSigners();
      const ownerAddress = await owner.getAddress();

      const value = BigNumber.from(1_000_000);
      const erc20 = testToken.address;

      await testToken.mint(ownerAddress, value);
      await testToken.approve(escrow.address, value);

      await escrow.deposit(ownerAddress, erc20, value);
      expect(await escrow.depositsOf(ownerAddress, erc20)).to.equal(value);
    });
  });

  describe('withdraw', function() {
    it('should work with native tokens', async function() {
      const { escrow } = await loadFixture(deployEscrow);

      const [owner, other] = await ethers.getSigners();
      const ownerAddress = await owner.getAddress();
      const otherAddress = await other.getAddress();

      const value = BigNumber.from(1_000_000);
      const erc20 = constants.AddressZero;
      await escrow.deposit(ownerAddress, erc20, value, { value });

      const balance = await other.getBalance();
      await escrow.withdraw(ownerAddress, otherAddress, erc20);
      expect(await other.getBalance()).to.equal(balance.add(value));
    });

    it('should work with erc20 tokens', async function() {
      const { escrow, testToken } = await loadFixture(deployEscrow);

      const [owner, other] = await ethers.getSigners();
      const ownerAddress = await owner.getAddress();
      const otherAddress = await other.getAddress();

      const value = BigNumber.from(1_000_000);
      const erc20 = testToken.address;

      await testToken.mint(ownerAddress, value);
      await testToken.approve(escrow.address, value);
      await escrow.deposit(ownerAddress, erc20, value);

      const balance = await testToken.balanceOf(otherAddress);
      await escrow.withdraw(ownerAddress, otherAddress, erc20);
      expect(await testToken.balanceOf(otherAddress)).to.equal(balance.add(value));
    });
  });
});

