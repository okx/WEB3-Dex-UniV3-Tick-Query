// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import "./contracts/AlgebraPool.sol";
import "./contracts/AlgebraFactory.sol";
import "./contracts/AlgebraPoolDeployer.sol";
import "./contracts/DataStorageOperator.sol";


import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "./contracts/test/TestERC20.sol";
contract TokenA is TestERC20 {
    constructor() TestERC20(100 ether) {
        mint(msg.sender, 100 ether);
    }

    function mint(uint256 amount) public {
        mint(msg.sender, amount);
    }
}

contract TokenB is TestERC20 {
    constructor() TestERC20(100 ether) {
        mint(msg.sender, 1 ether);
    }

    function mint(uint256 amount) public {
        mint(msg.sender, amount);
    }
}

contract Minter {
    TokenA tokenA;
    TokenB tokenB;
    AlgebraPool pool;

    constructor(TokenA _tokenA, TokenB _tokenB, AlgebraPool _pool) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        pool = _pool;
    }

    function mint() public {
        pool.mint(address(this), address(this), int24(-600), int24(120), 1 ether, "");
    }

    function mint2() public {
        pool.mint(address(this), address(this), int24(240), int24(360), 1 ether, "");
    }

    function algebraMintCallback(uint256 qty0, uint256 qty1, bytes memory data) public {
        tokenA.mint(qty0);
        tokenB.mint(qty1);
        tokenA.transfer(msg.sender, qty0);
        tokenB.transfer(msg.sender, qty1);
    }
}

contract AlgebraTest is Test {
    AlgebraFactory factory;
    AlgebraPoolDeployer deployer;
    AlgebraPool pool;
    TokenA tokenA;
    TokenB tokenB;
    Minter minter;

    function setUp() public {
        tokenB = new TokenB();
        tokenA = new TokenA();
        require(address(tokenA) < address(tokenB), "not ok");
        deployer = new AlgebraPoolDeployer();
        factory = new AlgebraFactory(address(deployer), address(this));
        deployer.setFactory(address(factory));
        pool = AlgebraPool(factory.createPool(address(tokenA), address(tokenB)));
        pool.initialize(uint160(1 << 96));
        minter = new Minter(tokenA, tokenB, pool);
    }

    function test_1() public {
        pool.tickSpacing();
        minter.mint();
        // pool.tickTreeRoot();
        pool.ticks(int24(-600));
        pool.ticks(int24(120));
        pool.tickTable(int16(-600 / int16(256)) - 1);
        pool.tickTable(int16(120 / int16(256)));
        // pool.tickSecondLayer(int16(-600 / int16(256) - 1 + 3466) / 
        pool.swap(address(this), true, type(int256).max, TickMath.getSqrtRatioAtTick(-887271),"");
    }
    function algebraSwapCallback(int256 amount0, int256 amount1, bytes memory) public {
        if (amount0 > 0) {
            address token = AlgebraPool(msg.sender).token0();
            TestERC20(token).mint(msg.sender, uint(amount0));
        }
        if (amount1 > 0) {
            address token = AlgebraPool(msg.sender).token1();
            TestERC20(token).mint(msg.sender, uint(amount1));
        }
    }
    fallback() external payable {}
}

