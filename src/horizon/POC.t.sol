pragma solidity 0.8.9;

import "@horizon/contracts/Factory.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@horizon/contracts/oracle/PoolOracle.sol";
import "forge-std/test.sol";
import "forge-std/console2.sol";

contract TokenA is ERC20 {
    constructor() ERC20("A", "A") {
        _mint(msg.sender, 100 ether);
    }

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}

contract TokenB is ERC20 {
    constructor() ERC20("B", "B") {
        _mint(msg.sender, 1 ether);
    }

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}

contract Minter {
    TokenA tokenA;
    TokenB tokenB;
    Pool pool;

    constructor(TokenA _tokenA, TokenB _tokenB, Pool _pool) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        pool = _pool;
    }

    function mint() public {
        int24[2] memory ticksPrevious = [int24(-887272), -887272];
        pool.mint(address(this), int24(-1), int24(0), ticksPrevious, 1 ether, "");
        pool.mint(address(this), int24(0), int24(1), ticksPrevious, 1 ether, "");
    }


    function mintCallback(uint256 qty0, uint256 qty1, bytes memory data) public {
        tokenA.mint(qty0);
        tokenB.mint(qty1);
        tokenA.transfer(msg.sender, qty0);
        tokenB.transfer(msg.sender, qty1);
    }
}
contract Swapper {
    TokenA tokenA;
    TokenB tokenB;
    Pool pool;

    constructor(TokenA _tokenA, TokenB _tokenB, Pool _pool) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        pool = _pool;
    }

    function swap() public {
        // pool.swap(address(this), int256(10**10), false, pool.getSqrtRatioAtTick(887272) - 1, "");
        console2.log("====================================================");
        pool.swap(address(this), int256(10**10), true, pool.getSqrtRatioAtTick(-887272) + 1, "");
        
    }


    function swapCallback(int256 qty0, int256 qty1, bytes memory data) public {
        if (qty0 > 0) {
            uint amount = uint(qty0);
            tokenA.mint(amount);

            tokenA.transfer(msg.sender, amount);

        }
        if (qty1 > 0 ){
            uint amount = uint(qty1);
            tokenB.mint(amount);

            tokenB.transfer(msg.sender, amount);
        }
        
    }
}

contract HorizonTest is Test {
    TokenA tokenA;
    TokenB tokenB;
    Factory factory;
    Pool pool;
    PoolOracle oracle;
    Minter minter;
    Swapper swapper;

    function setUp() public {
        tokenB = new TokenB();
        tokenA = new TokenA();
        require(address(tokenA) < address(tokenB), "must be");
        oracle = new PoolOracle();

        factory = new Factory(uint32(1 days), address(oracle));
        pool = Pool(factory.createPool(address(tokenA), address(tokenB), uint24(10)));
        minter = new Minter(tokenA, tokenB, pool);
        swapper = new Swapper(tokenA, tokenB, pool);
        tokenA.transfer(address(pool), 100);
        tokenB.transfer(address(pool), 100);
        pool.unlockPool(uint160(1 << 96));
        factory.addNFTManager(address(minter));
        pool.poolData();
        minter.mint();
    }

    function test_1() public {
        
        // minter.mint2();
        // pool.poolData();
        // bytes32 positionIndex = keccak256(abi.encodePacked(address(minter), int24(-2), int24(-1)));
        // (uint128 liquidity,) = pool.positions(positionIndex);
        // console2.log("l", liquidity);
        // (, int128 deltaL,,) = pool.ticks(int24(-2));
        // console2.log("deltaL", deltaL);
        // (, deltaL,,) = pool.ticks(int24(-1));
        // console2.log("deltaL", deltaL);
        // (int24 prev, int24 next) = pool.initializedTicks(int24(-2));
        // (prev, next) = pool.initializedTicks(int24(120));

        swapper.swap();
    }
}
