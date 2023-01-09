import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { deployCatalog } from './fixtures';

describe('Catalog', function () {
  describe('list', function() {
    it('should set item info', async function() {
      const { catalog } = await loadFixture(deployCatalog);

      const [owner] = await ethers.getSigners();
      const ownerAddress = await owner.getAddress();

      const config = 124;
      const uri = "ipfs://baf";
      await catalog.list(config, uri);

      const info = await catalog.itemInfo(0);
      expect(info.vendor).to.equal(ownerAddress);
      expect(info.config).to.equal(config);
      expect(info.uri).to.equal(uri);
    });
  });
});

