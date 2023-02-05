import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { BigNumber, constants } from 'ethers';
import { ethers } from 'hardhat';
import { deployEscrow } from './fixtures';

describe('Escrow.deposit', function() {
  it('should work with native tokens', async function() {
    const { escrow } = await loadFixture(deployEscrow);
    const [_, from, to] = await ethers.getSigners();

    const erc20 = constants.AddressZero;
    const value = BigNumber.from(1_000_000);

    await escrow.deposit(from.address, to.address, erc20, value, { value });
    expect(await escrow.depositsOf(to.address, erc20)).to.equal(value);
  });

  it('should work with erc20 tokens', async function() {
    const { escrow, token } = await loadFixture(deployEscrow);
    const [_, from, to] = await ethers.getSigners();

    const erc20 = token.address;
    const value = BigNumber.from(1_000_000);

    await token.connect(from).mint(from.address, value);
    await token.connect(from).approve(escrow.address, value);

    await escrow.deposit(from.address, to.address, erc20, value);
    expect(await escrow.depositsOf(to.address, erc20)).to.equal(value);
  });

  it('should revert when native token value not equal to amount', async function() {
    const { escrow } = await loadFixture(deployEscrow);
    const [_, from, to] = await ethers.getSigners();

    const erc20 = constants.AddressZero;
    const value = BigNumber.from(1_000_000);

    const tx = escrow.deposit(from.address, to.address, erc20, value, { value: value.sub(1) });
    await expect(tx).to.be.revertedWith('value must equal amount');
  });

  it('should revert when erc20 token value not equal to amount', async function() {
    const { escrow, token } = await loadFixture(deployEscrow);
    const [_, from, to] = await ethers.getSigners();

    const erc20 = token.address;
    const value = BigNumber.from(1_000_000);

    await token.connect(from).mint(from.address, value.sub(1));
    await token.connect(from).approve(escrow.address, value.sub(1));

    const tx = escrow.deposit(from.address, to.address, erc20, value);
    await expect(tx).to.be.revertedWith('ERC20: insufficient allowance');
  });

  it('should revert when sender is not owner', async function() {
    const { escrow } = await loadFixture(deployEscrow);
    const [_, from, to, sender] = await ethers.getSigners();

    const erc20 = constants.AddressZero;
    const value = BigNumber.from(1_000_000);

    const tx = escrow.connect(sender).deposit(from.address, to.address, erc20, value, { value });
    expect(tx).to.be.revertedWith('Ownable: caller is not the owner');
  });
});

describe('Escrow.withdraw', function() {
  it('should work with native tokens', async function() {
    const { escrow } = await loadFixture(deployEscrow);
    const [_, from, to, holding] = await ethers.getSigners();

    const erc20 = constants.AddressZero;
    const value = BigNumber.from(1_000_000);

    await escrow.deposit(from.address, to.address, erc20, value, { value });
    expect(await escrow.depositsOf(to.address, erc20)).to.equal(value);

    const beforeBalance = await holding.getBalance();
    await escrow.withdraw(to.address, holding.address, erc20);
    expect(await escrow.depositsOf(to.address, erc20)).to.equal(0);

    const afterBalance = await holding.getBalance();
    expect(afterBalance.sub(beforeBalance)).to.equal(value);
  });

  it('should work with erc20 tokens', async function() {
    const { escrow, token } = await loadFixture(deployEscrow);
    const [_, from, to, holding] = await ethers.getSigners();

    const erc20 = token.address;
    const value = BigNumber.from(1_000_000);

    await token.connect(from).mint(from.address, value);
    await token.connect(from).approve(escrow.address, value);

    await escrow.deposit(from.address, to.address, erc20, value);
    expect(await escrow.depositsOf(to.address, erc20)).to.equal(value);

    const beforeBalance = await token.balanceOf(holding.address);
    await escrow.withdraw(to.address, holding.address, erc20);
    expect(await escrow.depositsOf(to.address, erc20)).to.equal(0);

    const afterBalance = await token.balanceOf(holding.address);
    expect(afterBalance.sub(beforeBalance)).to.equal(value);
  });

  it('should revert when nothing to withdraw', async function() {
    const { escrow } = await loadFixture(deployEscrow);
    const [_, from, to] = await ethers.getSigners();

    const tx = escrow.withdraw(from.address, to.address, constants.AddressZero);
    await expect(tx).to.be.revertedWith('nothing to withdraw');
  });

  it('should revert when sender is not owner', async function() {
    const { escrow } = await loadFixture(deployEscrow);
    const [_, from, to, sender] = await ethers.getSigners();

    const tx = escrow.connect(sender).withdraw(from.address, to.address, constants.AddressZero);
    await expect(tx).to.be.revertedWith('Ownable: caller is not the owner');
  });
});