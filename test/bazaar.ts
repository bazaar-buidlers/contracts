import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { BigNumber, constants } from 'ethers';
import { ethers } from 'hardhat';
import { deployBazaar } from './fixtures';

describe('Bazaar.list', function() {
  it('should setup listing', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller] = await ethers.getSigners();

    await bazaar.connect(seller).list(1, 2, 3, "test");
    
    const uri = await bazaar.uri(0);
    expect(uri).to.equal("test");

    const [vendor, royalty] = await bazaar.royaltyInfo(0, 10000);
    expect(vendor).to.equal(seller.address)
    expect(royalty).to.equal(3);

    const info = await bazaar.listingInfo(0);
    expect(info.vendor).to.equal(seller.address);
    expect(info.supply).to.equal(0);
    expect(info.config).to.equal(1);
    expect(info.limit).to.equal(2);
    expect(info.royalty).to.equal(3);
    expect(info.uri).to.equal("test");
  });

  it('should revert when royalty is greater than fee denominator', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    
    const feeDenominator = await bazaar.feeDenominator();
    const royalty = feeDenominator.add(1);

    const tx = bazaar.list(0, 0, royalty, "test");
    await expect(tx).to.be.revertedWith('royalty will exceed sale price');
  });
});

describe('Bazaar.mint', function() {
  it('should work with native tokens', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [owner, seller, buyer] = await ethers.getSigners();

    const erc20s = [constants.AddressZero];
    const prices = [BigNumber.from(1_000_000)];

    await bazaar.connect(seller).list(0, 0, 0, "test");
    await bazaar.connect(seller).appraise(0, erc20s, prices);

    const amount = 2;
    const value = prices[0].mul(amount);

    await bazaar.connect(buyer).mint(buyer.address, 0, amount, erc20s[0], [], { value });
    expect(await bazaar.balanceOf(buyer.address, 0)).to.equal(amount);

    const info = await bazaar.listingInfo(0);
    expect(info.supply).to.equal(amount);

    const feeNumerator = await bazaar.feeNumerator();
    const feeDenominator = await bazaar.feeDenominator();

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

    await bazaar.connect(seller).list(0, 0, 0, "test");
    await bazaar.connect(seller).appraise(0, erc20s, prices);

    const amount = 2;
    const value = prices[0].mul(amount);

    await token.connect(buyer).mint(buyer.address, value);
    await token.connect(buyer).approve(escrow.address, value);

    await bazaar.connect(buyer).mint(buyer.address, 0, amount, erc20s[0], [], { value });
    expect(await bazaar.balanceOf(buyer.address, 0)).to.equal(amount);

    const info = await bazaar.listingInfo(0);
    expect(info.supply).to.equal(amount);

    const feeNumerator = await bazaar.feeNumerator();
    const feeDenominator = await bazaar.feeDenominator();

    const sellerDeposits = await bazaar.depositsOf(seller.address, erc20s[0]);
    const ownerDeposits = await bazaar.depositsOf(owner.address, erc20s[0]);

    const fee = feeNumerator.mul(value).div(feeDenominator);
    expect(ownerDeposits).to.equal(fee);
    expect(sellerDeposits).to.equal(value.sub(fee));
  });

  it('should work when listing is free', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();
    
    await bazaar.connect(seller).list(2, 0, 0, "test");
    await bazaar.connect(buyer).mint(buyer.address, 0, 1, constants.AddressZero, []);
    expect(await bazaar.balanceOf(buyer.address, 0)).to.equal(1);
  });

  it('should revert when listing is paused', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();
    
    await bazaar.connect(seller).list(1, 0, 0, "test");

    const tx = bazaar.connect(buyer).mint(buyer.address, 0, 1, constants.AddressZero, []);
    await expect(tx).to.be.revertedWith('minting is paused');
  });

  it('should revert when not appraised', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();
    
    await bazaar.connect(seller).list(0, 0, 0, "test");

    const tx = bazaar.connect(buyer).mint(buyer.address, 0, 1, constants.AddressZero, []);
    await expect(tx).to.be.revertedWith('invalid currency or amount');
  });

  it('should revert when limit is reached', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();

    const erc20s = [constants.AddressZero];
    const prices = [BigNumber.from(1_000_000)];

    await bazaar.connect(seller).list(0, 1, 0, "test");
    await bazaar.connect(seller).appraise(0, erc20s, prices);

    const tx = bazaar.connect(buyer).mint(buyer.address, 0, 2, erc20s[0], [], { value: prices[0].mul(2) });
    await expect(tx).to.be.revertedWith('token limit reached');
  });

  it('should revert when unique and already owned', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();

    const erc20s = [constants.AddressZero];
    const prices = [BigNumber.from(1_000_000)];

    await bazaar.connect(seller).list(8, 1, 0, "test");
    await bazaar.connect(seller).appraise(0, erc20s, prices);

    await bazaar.mint(buyer.address, 0, 1, erc20s[0], [], { value: prices[0] });
    expect(await bazaar.balanceOf(buyer.address, 0)).to.equal(1);

    const tx = bazaar.connect(buyer).mint(buyer.address, 0, 1, erc20s[0], [], { value: prices[0] });
    await expect(tx).to.be.revertedWith('token is unique');
  });
});

describe('Bazaar.appraise', function() {
  it('should set prices', async function() {
    const { bazaar, token } = await loadFixture(deployBazaar);
    const [_, seller] = await ethers.getSigners();

    const erc20s = [constants.AddressZero, token.address];
    const prices = [BigNumber.from(1_000_000), BigNumber.from(2_000_000)];

    await bazaar.connect(seller).list(0, 0, 0, "test");
    await bazaar.connect(seller).appraise(0, erc20s, prices);

    expect(await bazaar.priceInfo(0, erc20s[0])).to.equal(prices[0]);
    expect(await bazaar.priceInfo(0, erc20s[1])).to.equal(prices[1]);
  });

  it('should revert when sender is not vendor', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();

    const erc20s = [constants.AddressZero];
    const prices = [BigNumber.from(1_000_000)];

    await bazaar.connect(seller).list(0, 0, 0, "test");

    const tx = bazaar.connect(buyer).appraise(0, erc20s, prices);
    await expect(tx).to.be.revertedWith('sender is not vendor');
  });

  it('should revert when length of prices and erc20s are not equal', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller] = await ethers.getSigners();

    await bazaar.connect(seller).list(0, 0, 0, "test");

    const tx = bazaar.connect(seller).appraise(0, [constants.AddressZero], []);
    await expect(tx).to.be.revertedWith('mismatched erc20 and price');
  });
});

describe('Bazaar.configure', function() {
  it('should update listing', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller] = await ethers.getSigners();

    await bazaar.connect(seller).list(0, 0, 0, "test");
    await bazaar.connect(seller).configure(0, 1, 2, 3);

    const info = await bazaar.listingInfo(0);
    expect(info.config).to.equal(1);
    expect(info.limit).to.equal(2);
    expect(info.royalty).to.equal(3);
  });

  it('should revert when sender is not vendor', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();

    await bazaar.connect(seller).list(0, 0, 0, "test");

    const tx = bazaar.connect(buyer).configure(0, 1, 2, 3);
    await expect(tx).to.be.revertedWith('sender is not vendor');
  });

  it('should revert when supply is greater than limit', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();

    await bazaar.connect(seller).list(2, 0, 0, "test");
    await bazaar.connect(buyer).mint(buyer.address, 0, 2, constants.AddressZero, []);

    const tx = bazaar.connect(seller).configure(0, 2, 1, 0);
    expect(tx).to.be.revertedWith('limit lower than supply');
  });

  it('should revert when royalty is greater than fee denominator', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller] = await ethers.getSigners();

    await bazaar.connect(seller).list(0, 0, 0, "test");

    const feeDenominator = await bazaar.feeDenominator();
    const royalty = feeDenominator.add(1);

    const tx = bazaar.connect(seller).configure(0, 0, 0, royalty);
    await expect(tx).to.be.revertedWith('royalty will exceed sale price');
  });
});

describe('Bazaar.update', function() {
  it('should update uri', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller] = await ethers.getSigners();

    await bazaar.connect(seller).list(0, 0, 0, "test");
    await bazaar.connect(seller).update(0, "different");
    
    const info = await bazaar.listingInfo(0);
    expect(info.uri).to.equal("different");
    expect(await bazaar.uri(0)).to.equal("different");
  });

  it('should revert when sender is not vendor', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();

    await bazaar.connect(seller).list(0, 0, 0, "test");
    
    const tx = bazaar.connect(buyer).update(0, "two");
    await expect(tx).to.be.revertedWith('sender is not vendor');
  });
});

describe('Bazaar.transferVendor', function() {
  it('should update vendor', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();

    await bazaar.connect(seller).list(0, 0, 0, "test");
    await bazaar.connect(seller).transferVendor(0, buyer.address);
    
    const info = await bazaar.listingInfo(0);
    expect(info.vendor).to.equal(buyer.address);
  });

  it('should revert when sender is not vendor', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [_, seller, buyer] = await ethers.getSigners();

    await bazaar.connect(seller).list(0, 0, 0, "test");
    
    const tx = bazaar.connect(buyer).transferVendor(0, buyer.address);
    await expect(tx).to.be.revertedWith('sender is not vendor');
  });
});

describe('Bazaar.withdraw', function() {
  it('should work with native tokens', async function() {
    const { bazaar } = await loadFixture(deployBazaar);
    const [owner, seller, buyer, holding] = await ethers.getSigners();

    const erc20s = [constants.AddressZero];
    const prices = [BigNumber.from(1_000_000)];

    await bazaar.connect(seller).list(0, 0, 0, "test");
    await bazaar.connect(seller).appraise(0, erc20s, prices);

    const amount = 1;
    const value = prices[0].mul(amount);

    await bazaar.connect(buyer).mint(buyer.address, 0, amount, erc20s[0], [], { value });

    const feeNumerator = await bazaar.feeNumerator();
    const feeDenominator = await bazaar.feeDenominator();
    const fee = value.mul(feeNumerator).div(feeDenominator);

    const beforeBalance = await holding.getBalance();
    await bazaar.connect(seller).withdraw(holding.address, erc20s[0]);

    const afterBalance = await holding.getBalance();
    expect(afterBalance.sub(beforeBalance)).to.equal(value.sub(fee));

    await bazaar.withdraw(holding.address, erc20s[0]);
    expect(await holding.getBalance()).to.equal(beforeBalance.add(value));
  });

  it('should work with erc20 tokens', async function() {
    const { bazaar, escrow, token } = await loadFixture(deployBazaar);
    const [_, seller, buyer, holding] = await ethers.getSigners();

    const erc20s = [token.address];
    const prices = [BigNumber.from(1_000_000)];

    await bazaar.connect(seller).list(0, 0, 0, "test");
    await bazaar.connect(seller).appraise(0, erc20s, prices);

    const amount = 1;
    const value = prices[0].mul(amount);

    await token.connect(buyer).mint(buyer.address, value);
    await token.connect(buyer).approve(escrow.address, value);
    await bazaar.connect(buyer).mint(buyer.address, 0, amount, erc20s[0], []);

    const feeNumerator = await bazaar.feeNumerator();
    const feeDenominator = await bazaar.feeDenominator();
    const fee = value.mul(feeNumerator).div(feeDenominator);

    const beforeBalance = await token.balanceOf(holding.address);
    await bazaar.connect(seller).withdraw(holding.address, erc20s[0]);

    const afterBalance = await token.balanceOf(holding.address);
    expect(afterBalance.sub(beforeBalance)).to.equal(value.sub(fee));

    await bazaar.withdraw(holding.address, erc20s[0]);
    expect(await token.balanceOf(holding.address)).to.equal(beforeBalance.add(value));
  });
});