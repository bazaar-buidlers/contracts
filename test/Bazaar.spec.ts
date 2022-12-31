import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { deploy, list } from './fixtures';

describe('Bazaar', function () {
  describe('constructor', function() {
    it('should set owner and fee', async function () {
      const { bazaar, owner, feeNumerator, feeDenominator } = await loadFixture(deploy);

      expect(await bazaar.owner()).to.equal(owner);
      expect(await bazaar.feeNumerator()).to.equal(feeNumerator);
      expect(await bazaar.feeDenominator()).to.equal(feeDenominator);
    });
  });

  describe('list', function() {
    it('should set item info', async function() {
      const { bazaar, id, limit, config, tokenURI } = await loadFixture(list);

      const info = await bazaar.itemInfo(id);
      expect(info.limit).to.equal(limit);
      expect(info.config).to.equal(config);

      const uri = await bazaar.uri(id);
      expect(uri).to.equal(tokenURI);
    });
  });

  describe('mint', function() {
    it('should allow owner to mint for free', async function() {
      const { bazaar, owner, id } = await loadFixture(list);

      const tx = bazaar.mint(owner, id, ethers.constants.AddressZero);
      await expect(tx).to.emit(bazaar, 'TransferSingle');

      expect(await bazaar.balanceOf(owner, id)).to.equal(1);
    });

    it('should revert when price is not set', async function() {
      const { bazaar, owner, id } = await loadFixture(list);

      const [_, sender] = await ethers.getSigners();
      const senderAddress = await sender.getAddress();

      const tx = bazaar.connect(sender).mint(senderAddress, id, ethers.constants.AddressZero);
      await expect(tx).to.be.revertedWith('invalid currency');
    });
  });
});

