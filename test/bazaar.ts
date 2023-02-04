import { expect } from 'chai';
import { BigNumber, constants } from 'ethers';
import { ethers, upgrades } from 'hardhat';

describe('Bazaar', function() {
  it('should enable commerce', async function() {
    const [owner, seller, buyer, holding] = await ethers.getSigners();

    const Token = await ethers.getContractFactory('TestERC20');
    const token = await Token.deploy();

    const erc20s = [constants.AddressZero, token.address];
    const prices = [BigNumber.from(1_000_000), BigNumber.from(2_000_000)];

    const Escrow = await ethers.getContractFactory('Escrow');
    const escrow = await Escrow.deploy();

    const Bazaar = await ethers.getContractFactory('Bazaar');
    const bazaar = await upgrades.deployProxy(Bazaar, [300, escrow.address]);

    await escrow.transferOwnership(bazaar.address);
    await token.mint(buyer.address, 1_000_000_000);

    const feeNumerator = await bazaar.feeNumerator();
    const feeDenominator = await bazaar.FEE_DENOMINATOR();

    await bazaar.connect(seller).list(0, 0, 0, "ipfs://");
    await bazaar.connect(seller).appraise(0, erc20s, prices);

    expect(await bazaar.priceInfo(0, erc20s[0])).to.equal(prices[0]);
    expect(await bazaar.priceInfo(0, erc20s[1])).to.equal(prices[1]);

    // purchase with native tokens
    await bazaar.connect(buyer).mint(buyer.address, 0, 1, erc20s[0], [], { value: prices[0] });
    expect(await bazaar.balanceOf(buyer.address, 0)).to.equal(1);

    // purchase with erc20 tokens
    await token.connect(buyer).approve(escrow.address, prices[1]);
    await bazaar.connect(buyer).mint(buyer.address, 0, 1, erc20s[1], []);
    expect(await bazaar.balanceOf(buyer.address, 0)).to.equal(2);

    // check native token balances
    const nativeFee = prices[0].mul(feeNumerator).div(feeDenominator);
    const nativeDeposits = prices[0].sub(nativeFee);

    expect(await bazaar.depositsOf(owner.address, erc20s[0])).to.equal(nativeFee);
    expect(await bazaar.depositsOf(seller.address, erc20s[0])).to.equal(nativeDeposits);

    // check erc20 token balances
    const erc20Fee = prices[1].mul(feeNumerator).div(feeDenominator);
    const erc20Deposits = prices[1].sub(erc20Fee);

    expect(await bazaar.depositsOf(owner.address, erc20s[1])).to.equal(erc20Fee);
    expect(await bazaar.depositsOf(seller.address, erc20s[1])).to.equal(erc20Deposits);

    // get starting balances of holding account
    const nativeBalance = await holding.getBalance();
    const erc20Balance = await token.balanceOf(holding.address);

    // withdraw to holding account
    await bazaar.connect(seller).withdraw(holding.address, erc20s[0]);
    await bazaar.connect(seller).withdraw(holding.address, erc20s[1]);

    expect(await holding.getBalance()).to.equal(nativeBalance.add(nativeDeposits));
    expect(await token.balanceOf(holding.address)).to.equal(erc20Balance.add(erc20Deposits));

    expect(await bazaar.depositsOf(seller.address, erc20s[0])).to.equal(0);
    expect(await bazaar.depositsOf(seller.address, erc20s[1])).to.equal(0);
  });
});