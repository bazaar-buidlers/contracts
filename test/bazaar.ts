import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import { expect } from 'chai';
import { BigNumber, constants } from 'ethers';
import { ethers } from 'hardhat';
import { deployBazaar } from './fixtures';

const CONFIG_PAUSED = 1 << 0;
const CONFIG_FREE = 1 << 1;
const CONFIG_SOULBOUND = 1 << 2;
const CONFIG_UNIQUE = 1 << 3;

describe('Bazaar.list', function() {
  it('should setup listing', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller] = await ethers.getSigners();

    await bazaar.connect(seller).list(1, 2, 3, 4, "test");
    
    const uri = await bazaar.uri(0);
    expect(uri).to.equal("test");

    const [vendor, royalty] = await bazaar.royaltyInfo(0, 10000);
    expect(vendor).to.equal(seller.address)
    expect(royalty).to.equal(4);

    const info = await bazaar.listingInfo(0);
    expect(info.vendor).to.equal(seller.address);
    expect(info.supply).to.equal(0);
    expect(info.config).to.equal(1);
    expect(info.limit).to.equal(2);
    expect(info.allow).to.equal(3);
    expect(info.royalty).to.equal(4);
    expect(info.uri).to.equal("test");
  });

  it('should revert when royalty is greater than fee denominator', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    
    const feeDenominator = await bazaar.FEE_DENOMINATOR();
    const royalty = feeDenominator.add(1);

    const tx = bazaar.list(0, 0, 0, royalty, "test");
    await expect(tx).to.be.revertedWith('royalty will exceed sale price');
  });
});

describe('Bazaar.mint', function() {
  it('should work with native tokens', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [owner, seller, buyer] = await ethers.getSigners();

    const erc20s = [constants.AddressZero];
    const prices = [BigNumber.from(1_000_000)];

    await bazaar.connect(seller).list(0, 0, 0, 0, "test");
    await bazaar.connect(seller).appraise(0, erc20s, prices);

    const value = prices[0];

    await bazaar.connect(buyer).mint(0, buyer.address, erc20s[0], [], { value });
    expect(await bazaar.balanceOf(buyer.address, 0)).to.equal(1);

    const info = await bazaar.listingInfo(0);
    expect(info.supply).to.equal(1);

    const feeNumerator = await bazaar.feeNumerator();
    const feeDenominator = await bazaar.FEE_DENOMINATOR();

    const sellerDeposits = await bazaar.depositsOf(seller.address, erc20s[0]);
    const ownerDeposits = await bazaar.depositsOf(owner.address, erc20s[0]);

    const fee = feeNumerator.mul(value).div(feeDenominator);
    expect(ownerDeposits).to.equal(fee);
    expect(sellerDeposits).to.equal(value.sub(fee));
  });

  it('should work with erc20 tokens', async function() {
    const { bazaar, escrow, token } = await loadFixture(deployBazaar);
    const [owner, seller, buyer] = await ethers.getSigners();

    const erc20s = [token.address];
    const prices = [BigNumber.from(1_000_000)];

    await bazaar.connect(seller).list(0, 0, 0, 0, "test");
    await bazaar.connect(seller).appraise(0, erc20s, prices);

    const value = prices[0];

    await token.connect(buyer).mint(buyer.address, value);
    await token.connect(buyer).approve(escrow.address, value);

    await bazaar.connect(buyer).mint(0, buyer.address, erc20s[0], []);
    expect(await bazaar.balanceOf(buyer.address, 0)).to.equal(1);

    const info = await bazaar.listingInfo(0);
    expect(info.supply).to.equal(1);

    const feeNumerator = await bazaar.feeNumerator();
    const feeDenominator = await bazaar.FEE_DENOMINATOR();

    const sellerDeposits = await bazaar.depositsOf(seller.address, erc20s[0]);
    const ownerDeposits = await bazaar.depositsOf(owner.address, erc20s[0]);

    const fee = feeNumerator.mul(value).div(feeDenominator);
    expect(ownerDeposits).to.equal(fee);
    expect(sellerDeposits).to.equal(value.sub(fee));
  });

  it('should work when listing is free', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();
    
    await bazaar.connect(seller).list(CONFIG_FREE, 0, 0, 0, "test");
    await bazaar.connect(buyer).mint(0, buyer.address, constants.AddressZero, []);
    expect(await bazaar.balanceOf(buyer.address, 0)).to.equal(1);
  });

  it('should work when allow list contains address', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();

    const addresses = [[seller.address], [buyer.address]];
    const tree = StandardMerkleTree.of(addresses, ["address"]);
    const proof = tree.getProof([buyer.address]);
    
    await bazaar.connect(seller).list(CONFIG_FREE, 0, tree.root, 0, "test");
    await bazaar.connect(buyer).mint(0, buyer.address, constants.AddressZero, proof);
    expect(await bazaar.balanceOf(buyer.address, 0)).to.equal(1);
  });

  it('should revert when allow list proof does not match sender', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();

    const addresses = [[seller.address]];
    const tree = StandardMerkleTree.of(addresses, ["address"]);
    const proof = tree.getProof([seller.address]);
    
    await bazaar.connect(seller).list(CONFIG_FREE, 0, tree.root, 0, "test");

    const tx = bazaar.connect(buyer).mint(0, buyer.address, constants.AddressZero, proof);
    await expect(tx).to.be.revertedWith('not allowed');
  });

  it('should revert when listing is paused', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();
    
    await bazaar.connect(seller).list(CONFIG_PAUSED, 0, 0, 0, "test");

    const tx = bazaar.connect(buyer).mint(0, buyer.address, constants.AddressZero, []);
    await expect(tx).to.be.revertedWith('minting is paused');
  });

  it('should revert when not appraised', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();
    
    await bazaar.connect(seller).list(0, 0, 0, 0, "test");

    const tx = bazaar.connect(buyer).mint(0, buyer.address, constants.AddressZero, []);
    await expect(tx).to.be.revertedWith('invalid currency');
  });

  it('should revert when limit is reached', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();

    const erc20s = [constants.AddressZero];
    const prices = [BigNumber.from(1_000_000)];

    await bazaar.connect(seller).list(0, 1, 0, 0, "test");
    await bazaar.connect(seller).appraise(0, erc20s, prices);

    const value = prices[0];
    await bazaar.connect(buyer).mint(0, buyer.address, erc20s[0], [], { value });
    expect(await bazaar.balanceOf(buyer.address, 0)).to.equal(1);

    const tx = bazaar.connect(buyer).mint(0, buyer.address, erc20s[0], [], { value });
    await expect(tx).to.be.revertedWith('token limit reached');
  });

  it('should revert when unique and already owned', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();

    const erc20s = [constants.AddressZero];
    const prices = [BigNumber.from(1_000_000)];

    await bazaar.connect(seller).list(CONFIG_UNIQUE, 1, 0, 0, "test");
    await bazaar.connect(seller).appraise(0, erc20s, prices);

    const value = prices[0];
    await bazaar.mint(0, buyer.address, erc20s[0], [], { value });
    expect(await bazaar.balanceOf(buyer.address, 0)).to.equal(1);

    const tx = bazaar.connect(buyer).mint(0, buyer.address, erc20s[0], [], { value });
    await expect(tx).to.be.revertedWith('token is unique');
  });
});

describe('Bazaar.appraise', function() {
  it('should set prices', async function() {
    const { bazaar, token } = await loadFixture(deployBazaar);
    const [_, seller] = await ethers.getSigners();

    const erc20s = [constants.AddressZero, token.address];
    const prices = [BigNumber.from(1_000_000), BigNumber.from(2_000_000)];

    await bazaar.connect(seller).list(0, 0, 0, 0, "test");
    await bazaar.connect(seller).appraise(0, erc20s, prices);

    expect(await bazaar.priceInfo(0, erc20s[0])).to.equal(prices[0]);
    expect(await bazaar.priceInfo(0, erc20s[1])).to.equal(prices[1]);
  });

  it('should revert when sender is not vendor', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();

    const erc20s = [constants.AddressZero];
    const prices = [BigNumber.from(1_000_000)];

    await bazaar.connect(seller).list(0, 0, 0, 0, "test");

    const tx = bazaar.connect(buyer).appraise(0, erc20s, prices);
    await expect(tx).to.be.revertedWith('sender is not vendor');
  });

  it('should revert when length of prices and erc20s are not equal', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller] = await ethers.getSigners();

    await bazaar.connect(seller).list(0, 0, 0, 0, "test");

    const tx = bazaar.connect(seller).appraise(0, [constants.AddressZero], []);
    await expect(tx).to.be.revertedWith('mismatched erc20 and price');
  });
});

describe('Bazaar.configure', function() {
  it('should update listing', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller] = await ethers.getSigners();

    await bazaar.connect(seller).list(0, 0, 0, 0, "test");
    await bazaar.connect(seller).configure(0, 1, 2, 3, 4);

    const info = await bazaar.listingInfo(0);
    expect(info.config).to.equal(1);
    expect(info.limit).to.equal(2);
    expect(info.allow).to.equal(3);
    expect(info.royalty).to.equal(4);
  });

  it('should revert when sender is not vendor', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();

    await bazaar.connect(seller).list(0, 0, 0, 0, "test");

    const tx = bazaar.connect(buyer).configure(0, 1, 2, 3, 4);
    await expect(tx).to.be.revertedWith('sender is not vendor');
  });

  it('should revert when supply is greater than limit', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();

    await bazaar.connect(seller).list(CONFIG_FREE, 0, 0, 0, "test");
    await bazaar.connect(buyer).mint(0, buyer.address, constants.AddressZero, []);
    await bazaar.connect(buyer).mint(0, buyer.address, constants.AddressZero, []);

    const tx = bazaar.connect(seller).configure(0, CONFIG_FREE, 1, 0, 0);
    expect(tx).to.be.revertedWith('limit lower than supply');
  });

  it('should revert when royalty is greater than fee denominator', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller] = await ethers.getSigners();

    await bazaar.connect(seller).list(0, 0, 0, 0, "test");

    const feeDenominator = await bazaar.FEE_DENOMINATOR();
    const royalty = feeDenominator.add(1);

    const tx = bazaar.connect(seller).configure(0, 0, 0, 0, royalty);
    await expect(tx).to.be.revertedWith('royalty will exceed sale price');
  });

  it('should revert when locked', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();

    await bazaar.connect(seller).list(CONFIG_FREE | CONFIG_SOULBOUND, 0, 0, 0, "test");
    await bazaar.connect(buyer).mint(0, buyer.address, constants.AddressZero, []);

    // attempt to disable soulbound
    const tx1 = bazaar.connect(seller).configure(0, CONFIG_FREE, 0, 0, 0);
    await expect(tx1).to.be.revertedWith('config is locked');

    // attempt to enable unique
    const tx2 = bazaar.connect(seller).configure(0, CONFIG_FREE | CONFIG_SOULBOUND | CONFIG_UNIQUE, 0, 0, 0);
    await expect(tx2).to.be.revertedWith('config is locked');
  });
});

describe('Bazaar.update', function() {
  it('should update uri', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller] = await ethers.getSigners();

    await bazaar.connect(seller).list(0, 0, 0, 0, "test");
    await bazaar.connect(seller).update(0, "different");
    
    const info = await bazaar.listingInfo(0);
    expect(info.uri).to.equal("different");
    expect(await bazaar.uri(0)).to.equal("different");
  });

  it('should revert when sender is not vendor', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();

    await bazaar.connect(seller).list(0, 0, 0, 0, "test");
    
    const tx = bazaar.connect(buyer).update(0, "two");
    await expect(tx).to.be.revertedWith('sender is not vendor');
  });
});

describe('Bazaar.transferVendor', function() {
  it('should update vendor', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();

    await bazaar.connect(seller).list(0, 0, 0, 0, "test");
    await bazaar.connect(seller).transferVendor(0, buyer.address);
    
    const info = await bazaar.listingInfo(0);
    expect(info.vendor).to.equal(buyer.address);
  });

  it('should revert when sender is not vendor', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();

    await bazaar.connect(seller).list(0, 0, 0, 0, "test");
    
    const tx = bazaar.connect(buyer).transferVendor(0, buyer.address);
    await expect(tx).to.be.revertedWith('sender is not vendor');
  });
});
