import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { BigNumber } from 'ethers';
import * as fixtures from './fixtures';

const zeroAddress = ethers.constants.AddressZero;

describe('Bazaar', function () {
  describe('constructor', function() {
    it('should set owner and fee', async function () {
      const { bazaar, owner, feeNumerator, feeDenominator } = await loadFixture(fixtures.deploy);

      expect(await bazaar.owner()).to.equal(owner);
      expect(await bazaar.feeNumerator()).to.equal(feeNumerator);
      expect(await bazaar.feeDenominator()).to.equal(feeDenominator);
    });
  });

  describe('list', function() {
    it('should set item info', async function() {
      const { bazaar } = await loadFixture(fixtures.deploy);

      const id = 0;
      const limit = BigNumber.from(ethers.utils.randomBytes(4));
      const config = BigNumber.from(ethers.utils.randomBytes(4));
      const tokenURI = ethers.utils.hexlify(ethers.utils.randomBytes(64));

      await bazaar.list(limit, config, tokenURI);
      expect(await bazaar.uri(0)).to.equal(tokenURI);

      const info = await bazaar.itemInfo(id);
      expect(info.limit).to.equal(limit);
      expect(info.config).to.equal(config);
    });
  });

  describe('appraise', function() {
    it('should set price for each token', async function() {
      const { bazaar, testToken, items } = await loadFixture(fixtures.appraise);

      const item = items[0];
      const erc20s = [zeroAddress, testToken.address];
      const prices = [1_000_000_000, 2_000_000_000];

      await bazaar.appraise(item.id, erc20s, prices);
      expect(await bazaar.priceInfo(item.id, erc20s[0])).to.equal(prices[0]);
      expect(await bazaar.priceInfo(item.id, erc20s[1])).to.equal(prices[1]);
    });
  });

  describe('mint', function() {
    it('should allow owner to mint for free', async function() {
      const { bazaar, owner, items } = await loadFixture(fixtures.list);
      
      const item = items[0];
      const amount = 3;

      await bazaar.mint(owner, item.id, amount, zeroAddress);
      expect(await bazaar.balanceOf(owner, item.id)).to.equal(amount);
    });

    it('should allow to mint when item is free', async function() {
      const { bazaar, items } = await loadFixture(fixtures.list);
      
      const [_, sender] = await ethers.getSigners();
      const senderAddress = await sender.getAddress();

      const item = items[2];
      const amount = 5;

      await bazaar.connect(sender).mint(senderAddress, item.id, amount, zeroAddress);
      expect(await bazaar.balanceOf(senderAddress, item.id)).to.equal(amount);
    });

    it('should revert when minting is paused', async function() {
      const { bazaar, owner, items } = await loadFixture(fixtures.list);
      
      const item = items[1];
      const amount = 1;

      await expect(bazaar.mint(owner, item.id, amount, zeroAddress)).to.be.revertedWith('minting is paused');
    });

    it('should revert when item is unique', async function() {
      const { bazaar, owner, items } = await loadFixture(fixtures.list);
      
      const item = items[4];
      const amount = 2;

      await expect(bazaar.mint(owner, item.id, amount, zeroAddress)).to.be.revertedWith('item is unique');
    });

    it('should revert when limit is reached', async function() {
      const { bazaar, owner, items } = await loadFixture(fixtures.list);
      
      const item = items[0];
      const amount = item.limit + 1;

      await expect(bazaar.mint(owner, item.id, amount, zeroAddress)).to.be.revertedWith('limit reached');
    });

    it('should revert when price is not set', async function() {
      const { bazaar, owner, items } = await loadFixture(fixtures.list);

      const item = items[0];
      const amount = 1;

      const [_, sender] = await ethers.getSigners();
      const senderAddress = await sender.getAddress();

      const tx = bazaar.connect(sender).mint(senderAddress, item.id, amount, zeroAddress);
      await expect(tx).to.be.revertedWith('invalid currency or amount');
    });

    it('should revert when native token value is too low', async function() {
      const { bazaar, items } = await loadFixture(fixtures.appraise);

      const item = items[0];
      const amount = 2;

      const [_, sender] = await ethers.getSigners();
      const senderAddress = await sender.getAddress();

      await expect(bazaar.connect(sender).mint(senderAddress, item.id, amount, zeroAddress)).to.be.revertedWith('value too low');
    });

    it('should revert when erc20 allowance is too low', async function() {
      const { bazaar, testToken, items } = await loadFixture(fixtures.appraise);

      const item = items[0];
      const amount = 2;

      const [_, sender] = await ethers.getSigners();
      const senderAddress = await sender.getAddress();

      await expect(bazaar.connect(sender).mint(senderAddress, item.id, amount, testToken.address)).to.be.revertedWith('ERC20: insufficient allowance');
    });

    it('should work with native tokens', async function() {
      const { bazaar, items } = await loadFixture(fixtures.appraise);

      const item = items[0];
      const amount = 2;

      const price = await bazaar.priceInfo(item.id, zeroAddress);
      const value = price * amount;

      const [_, sender] = await ethers.getSigners();
      const senderAddress = await sender.getAddress();

      await bazaar.connect(sender).mint(senderAddress, item.id, amount, zeroAddress, { value });
      expect(await bazaar.balanceOf(senderAddress, item.id)).to.equal(amount);
    });

    it('should work with erc20 tokens', async function() {
      const { bazaar, testToken, items } = await loadFixture(fixtures.appraise);
      
      const item = items[0];
      const amount = 2;

      const price = await bazaar.priceInfo(item.id, testToken.address);
      const value = price * amount;

      const [_, sender] = await ethers.getSigners();
      const senderAddress = await sender.getAddress();

      await testToken.mint(senderAddress, value);
      await testToken.connect(sender).approve(bazaar.address, value);

      await bazaar.connect(sender).mint(senderAddress, item.id, amount, testToken.address, { value });
      expect(await bazaar.balanceOf(senderAddress, item.id)).to.equal(amount);
    });
  });
});

