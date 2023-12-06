// 1. pool地址
// 2. pool拿到tick
// 3. 开始计算: swap tick deltaL, amountIn, amountOut, sqrtP
// step by step swap
pragma solidity >=0.5.0 <0.8.0;
pragma abicoder v2;

import "forge-std/console2.sol";
import "forge-std/test.sol";
import {RamsesV2Pool} from "./factory/RamsesV2Factory/contracts/V2/RamsesV2Pool.sol";
import "solmate/tokens/ERC20.sol";

contract TokenA is ERC20 {
    constructor() ERC20("A", "A", 18) {
        _mint(msg.sender, 100 ether);
    }

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}

contract TokenB is ERC20 {
    constructor() ERC20("B", "B", 18) {
        _mint(msg.sender, 1 ether);
    }

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}

contract Minter {
    TokenA tokenA;
    TokenB tokenB;
    RamsesV2Pool pool;

    constructor(TokenA _tokenA, TokenB _tokenB, RamsesV2Pool _pool) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        pool = _pool;
    }

    function mint(int24 a, int24 b, uint128 amount) public {
        pool.mint(address(this), a, b, amount, "");
    }

    function burn(int24 a, int24 b, uint128 amount) public {
        pool.burn(a, b, amount);
    }

    function ramsesV2MintCallback(uint256 x, uint256 y, bytes calldata data) external {
        tokenA.mint(x);
        tokenB.mint(y);
        tokenA.transfer(msg.sender, x);
        tokenB.transfer(msg.sender, y);
    }
}

contract Swapper {
    TokenA tokenA;
    TokenB tokenB;
    RamsesV2Pool pool;

    constructor(TokenA _tokenA, TokenB _tokenB, RamsesV2Pool _pool) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        pool = _pool;
    }

    function swap(bool zeroForOne, int256 amountIn) public {
        uint160 sqrtP = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342 - 1;
        if (zeroForOne) {
            sqrtP = 4_295_128_739 + 1;
        }
        (int256 amount0, int256 amount1) = pool.swap(address(this), zeroForOne, amountIn, sqrtP, "");
        console2.log("amount0: %d", amount0);
        console2.log("amount1: %d", amount1);
    }

    function ramsesV2SwapCallback(int256 x, int256 y, bytes calldata data) external {
        if (x > 0) {
            tokenA.mint(uint256(x));
            tokenA.transfer(msg.sender, uint256(x));
        }
        if (y > 0) {
            tokenB.mint(uint256(y));
            tokenB.transfer(msg.sender, uint256(y));
        }
    }
}

// address: https://arbiscan.io/address/0x562d29b54d2c57F8620C920415C4dCEAdD6dE2d2
// deltaL: 0x000000000000000000000000000000000000000000000000003c198be70ceb4b00000000000000000000000000000001ffffffffffffffffffc3d6cde38ee52700000000000000000000000000000014ffffffffffffffffffffffff8c6305d0000000000000000000000000000d89a0fffffffffffffffffffffffffffe7964ffffffffffffffffffffffffffffffff000000000000000000000fa635642f8effffffffffffffffffffffffffffffec000000000000000000000000739cfa30fffffffffffffffffffffffffff276600000000000000000000000000001869c
contract Deployer is Test {
    string toFile = "src/solidly/to1.txt";
    TokenA public tokenA;
    TokenB public tokenB;
    RamsesV2Pool public pool;
    Minter public minter;
    Swapper public swapper;

    function deploy() public {
        tokenB = new TokenB();
        tokenA = new TokenA();

        require(address(tokenA) < address(tokenB), "must be");
        pool = new RamsesV2Pool();
        pool.initialize(
            address(this),
            address(this),
            address(this),
            address(this),
            address(tokenA),
            address(tokenB),
            uint24(50),
            int24(1)
        );
        pool.setSlot0(
            uint160(79229504437066823001182789432),
            int24(0),
            uint16(850),
            uint16(1000),
            uint16(2000),
            uint8(102),
            true
        );
        minter = new Minter(tokenA, tokenB, pool);
        swapper = new Swapper(tokenA, tokenB, pool);
    }

    function preset() public {
        int24 tickA;
        int24 tickB;
        int128 deltaL;
        int128 carryL = 0;
        tickA = int24(vm.parseInt(vm.readLine(toFile)));
        for (uint256 i = 0; i < 7 - 1; i++) {
            deltaL = int128(vm.parseInt(vm.readLine(toFile)));
            tickB = int24(vm.parseInt(vm.readLine(toFile)));
            int128 amountL = carryL + deltaL;
            if (amountL > 0) {
                minter.mint(tickA, tickB, uint128(amountL));
            } else {
                minter.burn(tickA, tickB, uint128(amountL));
            }
            carryL += deltaL;
            tickA = tickB;
        }
    }

    ERC20 USDC = ERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    ERC20 USDC_e = ERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    RamsesV2Pool USDC_USDC_e = RamsesV2Pool(0x562d29b54d2c57F8620C920415C4dCEAdD6dE2d2);

    function swapCompare(bool zeroForOne, uint256 amount) public {
        deal(address(USDC), address(this), amount);
        deal(address(USDC_e), address(this), amount);
        uint160 sqrtP = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342 - 1;
        if (zeroForOne) {
            sqrtP = 4_295_128_739 + 1;
        }
        (int256 amount0, int256 amount1) = USDC_USDC_e.swap(address(this), zeroForOne, int256(amount), sqrtP, "");
        console2.log("amount0: %d", amount0);
        console2.log("amount1: %d", amount1);
    }

    function ramsesV2SwapCallback(int256 x, int256 y, bytes calldata data) external {
        if (x > 0) {
            USDC.transfer(msg.sender, uint256(x));
        }
        if (y > 0) {
            USDC_e.transfer(msg.sender, uint256(y));
        }
    }
}

contract POC is Test {
    string toFile = "src/solidly/to1.txt";
    Deployer deployer;

    function setUp() public {
        
    }

    function _test_1() public {
        vm.createSelectFork("https://arbitrum.llamarpc.com", 156_744_473);
        deployer = new Deployer();
        deployer.deploy();
        deployer.preset();

        RamsesV2Pool USDC_USDC_e = RamsesV2Pool(0x562d29b54d2c57F8620C920415C4dCEAdD6dE2d2);
        (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        ) = USDC_USDC_e.slot0();
        console2.log(uint256(sqrtPriceX96));
        console2.log(int256(tick));
        console2.log(uint256(feeProtocol));

        deployer.swapCompare(true, 100_000 ether);
    }

    function test_2() public {
        vm.createSelectFork("https://arbitrum.llamarpc.com", 157318163);
        deployer = new Deployer();
        deployer.deploy();
        deployer.preset();
        (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        ) = deployer.pool().slot0();
        console2.log(uint256(sqrtPriceX96));
        console2.log(int256(tick));
        console2.log(uint256(feeProtocol));
        deployer.swapper().swap(true, 100_000 ether);
    }

    function _test_preset() public {
        vm.createSelectFork("https://arbitrum.llamarpc.com", 157318163);
        RamsesV2Pool pool = RamsesV2Pool(0x562d29b54d2c57F8620C920415C4dCEAdD6dE2d2);
        int24 tickSpacing = pool.tickSpacing();
        int24 leftMost = -887_272 / tickSpacing / int24(256) - 2;
        int24 rightMost = 887_272 / tickSpacing / int24(256) + 1;

        int24 right = leftMost + 1;
        uint256 index;
        uint256 index2;

        while (right < rightMost) {
            uint256 res = pool.tickBitmap(int16(right));
            if (res > 0) {
                for (uint256 i = 0; i < 256; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int256 tick = int256((256 * right + int256(i)) * tickSpacing);
                        (, int128 liquidityNet,,,,,,,,) = pool.ticks(int24(tick));
                        vm.writeLine(toFile, vm.toString(tick));
                        vm.writeLine(toFile, vm.toString(liquidityNet));
                        index++;
                    }

                    res = res >> 1;
                }
            }

            right++;
        }
        vm.writeLine(toFile, vm.toString(index));
         (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        ) = pool.slot0();
        vm.writeLine(toFile, vm.toString(tick));
        vm.writeLine(toFile, vm.toString(uint(sqrtPriceX96)));
    }
}
