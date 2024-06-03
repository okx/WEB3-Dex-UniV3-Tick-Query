import { Wallet } from 'ethers';
import { ethers } from 'hardhat';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from './shared/expect';

import { poolFixture } from './shared/fixtures';

import {
  createPoolFunctions,
  PoolFunctions,
  createMultiPoolFunctions,
  encodePriceSqrt,
  getMinTick,
  getMaxTick,
  expandTo18Decimals,
} from './shared/utilities';

import { MockTimeAlgebraPool, TestERC20, AlgebraFactory, TestAlgebraRouter, TestAlgebraCallee } from '../typechain';

const tickSpacing = 60;

type ThenArg<T> = T extends PromiseLike<infer U> ? U : T;

describe('AlgebraPoolRouter', () => {
  let wallet: Wallet, other: Wallet;

  let token0: TestERC20;
  let token1: TestERC20;
  let token2: TestERC20;
  let factory: AlgebraFactory;
  let pool0: MockTimeAlgebraPool;
  let pool1: MockTimeAlgebraPool;

  let pool0Functions: PoolFunctions;
  let pool1Functions: PoolFunctions;

  let minTick: number;
  let maxTick: number;

  let swapTargetCallee: TestAlgebraCallee;
  let swapTargetRouter: TestAlgebraRouter;

  let createPool: ThenArg<ReturnType<typeof poolFixture>>['createPool'];

  before('create fixture loader', async () => {
    [wallet, other] = await (ethers as any).getSigners();
  });

  beforeEach('deploy first fixture', async () => {
    ({ token0, token1, token2, factory, createPool, swapTargetCallee, swapTargetRouter } = await loadFixture(
      poolFixture
    ));

    const createPoolWrapped = async (
      firstToken: TestERC20,
      secondToken: TestERC20
    ): Promise<[MockTimeAlgebraPool, any]> => {
      const pool = await createPool(firstToken, secondToken);
      const poolFunctions = createPoolFunctions({
        swapTarget: swapTargetCallee,
        token0: firstToken,
        token1: secondToken,
        pool,
      });
      minTick = getMinTick(tickSpacing);
      maxTick = getMaxTick(tickSpacing);
      return [pool, poolFunctions];
    };

    // default to the 30 bips pool
    [pool0, pool0Functions] = await createPoolWrapped(token0, token1);
    [pool1, pool1Functions] = await createPoolWrapped(token1, token2);
  });

  it('constructor initializes immutables', async () => {
    expect(await pool0.factory()).to.eq(await factory.getAddress());
    expect(await pool0.token0()).to.eq(await token0.getAddress());
    expect(await pool0.token1()).to.eq(await token1.getAddress());
    expect(await pool1.factory()).to.eq(await factory.getAddress());
    expect(await pool1.token0()).to.eq(await token1.getAddress());
    expect(await pool1.token1()).to.eq(await token2.getAddress());
  });

  describe('multi-swaps', () => {
    let inputToken: TestERC20;
    let outputToken: TestERC20;

    beforeEach('initialize both pools', async () => {
      inputToken = token0;
      outputToken = token2;

      await pool0.initialize(encodePriceSqrt(1, 1));
      await pool1.initialize(encodePriceSqrt(1, 1));

      await pool0Functions.mint(wallet.address, minTick, maxTick, expandTo18Decimals(1));
      await pool1Functions.mint(wallet.address, minTick, maxTick, expandTo18Decimals(1));
    });

    it('multi-swap', async () => {
      const token0OfPoolOutput = await pool1.token0();
      expect(token0OfPoolOutput).to.be.oneOf([await token1.getAddress(), await token2.getAddress()]);
      const ForExact0 = await outputToken.getAddress() === token0OfPoolOutput;

      const { swapForExact0Multi, swapForExact1Multi } = createMultiPoolFunctions({
        inputToken: token0,
        swapTarget: swapTargetRouter,
        poolInput: pool0,
        poolOutput: pool1,
      });

      const method = ForExact0 ? swapForExact0Multi : swapForExact1Multi;

      const [pool0Address, pool1Address, inputTokenAddress] = [
        await pool0.getAddress(),
        await pool1.getAddress(),
        await inputToken.getAddress()
      ]
      await expect(method(100, wallet.address))
        .to.emit(outputToken, 'Transfer')
        .withArgs(pool1Address, wallet.address, 100)
        .to.emit(token1, 'Transfer')
        .withArgs(pool0Address, pool1Address, 102)
        .to.emit(inputToken, 'Transfer')
        .withArgs(wallet.address, pool0Address, 104);
    });
  });
});
