pragma solidity 0.8.9;

import "forge-std/console2.sol";
import "forge-std/test.sol";
import "@izumi/contracts/iZiSwapFactory.sol";
import "@izumi/contracts/swapX2Y.sol";
import "@izumi/contracts/swapY2X.sol";
import "@izumi/contracts/liquidity.sol";
import "@izumi/contracts/limitOrder.sol";
import "@izumi/contracts/flash.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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
    iZiSwapPool pool;

    constructor(TokenA _tokenA, TokenB _tokenB, iZiSwapPool _pool) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        pool = _pool;
    }

    function mint() public {
        pool.mint(address(this), int24(-600), int24(120), 1 ether, "");
    }

    function mint2() public {
        pool.mint(address(this), int24(100), int24(360), 1 ether, "");
    }

    function mintDepositCallback(uint256 x, uint256 y, bytes calldata data) external {
        tokenA.mint(x);
        tokenB.mint(y);
        tokenA.transfer(msg.sender, x);
        tokenB.transfer(msg.sender, y);
    }
}

contract Order {
    TokenA tokenA;
    TokenB tokenB;
    iZiSwapPool pool;

    constructor(TokenA _tokenA, TokenB _tokenB, iZiSwapPool _pool) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        pool = _pool;
    }

    function addLimitOrderX() public {
        pool.addLimOrderWithX(address(this), int24(100), 1 ether, "");
    }

    function addLimitOrderY() public {
        pool.addLimOrderWithY(address(this), int24(-100), 1 ether, "");
    }

    function payCallback(uint256 x, uint256 y, bytes calldata data) external {
        tokenA.mint(x);
        tokenB.mint(y);
        tokenA.transfer(msg.sender, x);
        tokenB.transfer(msg.sender, y);
    }
}

contract Swapper {
    TokenA tokenA;
    TokenB tokenB;
    iZiSwapPool pool;

    constructor(TokenA _tokenA, TokenB _tokenB, iZiSwapPool _pool) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        pool = _pool;
    }

    function swap() public {
        pool.swapY2X(address(this), 2 ether, int24(1001), "");
    }

    function swapY2XCallback(uint256 x, uint256 y, bytes calldata data) external {
        _swap(x, y);
    }

    function _swap(uint256 x, uint256 y) internal {
        tokenA.mint(x);
        tokenB.mint(y);
        tokenA.transfer(msg.sender, x);
        tokenB.transfer(msg.sender, y);
    }

    function swapX2YCallback(uint256 x, uint256 y, bytes calldata data) external {
        _swap(x, y);
    }
}

contract IzumiTest is Test {
    iZiSwapFactory factory;
    iZiSwapPool pool;
    TokenA tokenA;
    TokenB tokenB;
    Minter minter;
    Order order;
    Swapper swapper;

    function setUp() public {
        tokenB = new TokenB();
        tokenA = new TokenA();
        require(address(tokenA) < address(tokenB), "must be");

        address swapX2YModule = address(new SwapX2YModule());
        address swapY2XModule = address(new SwapY2XModule());
        address liquidity = address(new LiquidityModule());
        address limitOrder = address(new LimitOrderModule());
        address flashModule = address(new FlashModule());
        factory =
            new iZiSwapFactory(address(this), swapX2YModule, swapY2XModule, liquidity, limitOrder, flashModule, 0x32);

        pool = iZiSwapPool(factory.newPool(address(tokenA), address(tokenB), uint24(100), int24(0)));
        minter = new Minter(tokenA, tokenB, pool);
        order = new Order(tokenA, tokenB, pool);
        swapper = new Swapper(tokenA, tokenB, pool);
    }

    function _test_1() public {
        // minter.mint();
        order.addLimitOrderX();
        pool.points(int24(100));
        pool.orderOrEndpoint(int24(100));
        pool.limitOrderData(int24(100));
        pool.userEarnX(keccak256(abi.encodePacked(address(order), int24(100))));
        pool.pointDelta();
        pool.pointBitmap(0); //100/256=0

        swapper.swap();

        pool.points(int24(100));
        pool.orderOrEndpoint(int24(100));
        pool.limitOrderData(int24(100));
        pool.userEarnX(keccak256(abi.encodePacked(address(order), int24(100))));
        pool.pointDelta();
        pool.pointBitmap(0); //100/256=0
    }

    function test_2() public {
        minter.mint();
        // minter.mint2();
        pool.points(int24(-600));
        pool.points(int24(120));

        pool.points(int24(100));
        pool.points(int24(360));
        pool.orderOrEndpoint(int24(-600));
        pool.pointDelta();
        pool.pointBitmap(0); //120//256=0
        pool.pointBitmap(-3); //600/256+1=-3

        swapper.swap();

        pool.points(int24(-600));
        pool.points(int24(120));
        pool.orderOrEndpoint(int24(-600));
        pool.limitOrderData(int24(-600));

        pool.pointDelta();
        pool.pointBitmap(0); //100/256=0
    }
}
