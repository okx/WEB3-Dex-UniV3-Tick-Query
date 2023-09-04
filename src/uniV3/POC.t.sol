pragma solidity >=0.7.0;
pragma abicoder v2;

import "forge-std/console2.sol";
import "forge-std/test.sol";

import "@UniswapV3/core/contracts/UniswapV3Pool.sol";
import "@UniswapV3/core/contracts/UniswapV3Factory.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "solmate/tokens/ERC20.sol";

contract TokenA is ERC20 {
    constructor() ERC20("FXS", "FXS", 18) {}

    function mint(address user, uint256 amount) public {
        _mint(user, amount);
    }
}

contract TokenB is ERC20 {
    constructor() ERC20("USDT", "USDT", 18) {}

    function mint(address user, uint256 amount) public {
        _mint(user, amount);
    }
}

contract Minter {
    TokenA tokenA;
    TokenB tokenB;
    UniswapV3Pool pool;

    constructor(TokenA _tokenA, TokenB _tokenB, UniswapV3Pool _pool) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        pool = _pool;
    }

    function mint() public {
        pool.mint(address(this), int24(-2), int24(-1), 1 ether, "");
        pool.mint(address(this), int24(0), int24(10), 1 ether, "");
        
    }

    function uniswapV3MintCallback(uint256 qty0, uint256 qty1, bytes memory data)
        public
    {
        tokenA.mint(msg.sender, qty0);
        tokenB.mint(msg.sender, qty1);
    }
}

contract Swapper {
    TokenA tokenA;
    TokenB tokenB;
    UniswapV3Pool pool;

    constructor(TokenA _tokenA, TokenB _tokenB, UniswapV3Pool _pool) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        pool = _pool;
    }

    function swap() public {
        pool.swap(address(this), false, int256(10**10), pool.getSqrtRatioAtTick(200) - 1, "");
        // pool.swap(address(this), true, int256(1 ether), pool.getSqrtRatioAtTick(-200) + 1, "");
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        if (amount0Delta > 0) {
            tokenA.mint(msg.sender, uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            tokenB.mint(msg.sender, uint256(amount1Delta));
        }
    }
}

contract UniV3Test is Test {
    TokenA tokenA;
    TokenB tokenB;
    UniswapV3Pool pool;
    UniswapV3Factory factory;
    Minter minter;
    Swapper swapper;

    function setUp() public {
        tokenB = new TokenB();
        tokenA = new TokenA();
        require(address(tokenA) < address(tokenB), "not ok");
        factory = new UniswapV3Factory();
        pool = UniswapV3Pool(
            factory.createPool(address(tokenA), address(tokenB), uint24(100))
        );
        pool.initialize(pool.getSqrtRatioAtTick(0));
        minter = new Minter(tokenA, tokenB, pool);
        swapper = new Swapper(tokenA, tokenB, pool);
        minter.mint();
    }

    function test_1() public {
        swapper.swap();
    }
    


}
