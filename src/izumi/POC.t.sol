pragma solidity 0.8.9;

import "forge-std/console2.sol";
import "forge-std/test.sol";
import "@izumi/contracts/iZiSwapFactory.sol";
import "@izumi/contracts/swapX2Y.sol";
import "@izumi/contracts/swapY2X.sol";
import "@izumi/contracts/liquidity.sol";
import "@izumi/contracts/limitOrder.sol";
import "@izumi/contracts/flash.sol";
import "@izumi/contracts/libraries/State.sol";
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
        pool.mint(address(this), int24(-600), int24(120), 0.1 ether, "");
    }

    function mint2() public {
        pool.mint(address(this), int24(100), int24(360), 0.1 ether, "");
    }

    function mint(int24 a, int24 b, uint128 amount) public {
        pool.mint(address(this), a, b, amount, "");
    }

    function burn(int24 a, int24 b, uint128 amount) public {
        pool.burn(a, b, amount);
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
        pool.addLimOrderWithX(address(this), int24(100), 0.1 ether, "");
    }

    function addLimitOrderY() public {
        pool.addLimOrderWithY(address(this), int24(-100), 0.1 ether, "");
    }

    function addLimitOrderY(int24 a, uint128 amount) public {
        if (amount == 0) return;
        pool.addLimOrderWithY(address(this), a, amount, "");
    }

    function addLimitOrderX(int24 a, uint128 amount) public {
        if (amount == 0) return;
        pool.addLimOrderWithX(address(this), a, amount, "");
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

    function swapX2Y() public {
        pool.swapX2Y(address(this), 0.1 ether, int24(-887272) / 40 * 40, "");
    }

    function swapY2X() public {
        pool.swapY2X(address(this), 100e6, int24(887272) / 40 * 40, "");
    }

    function swapY2XCallback(uint256 x, uint256 y, bytes calldata data) external {
        console2.log("=========SWAP RES=========");
        console2.log(x);
        console2.log(y);
        _swap(x, y, false);
    }

    function _swap(uint256 x, uint256 y, bool isX) internal {
        if (isX) {
            tokenA.mint(x);
            tokenA.transfer(msg.sender, x);
        } else {
            tokenB.mint(y);
            tokenB.transfer(msg.sender, y);
        }
    }

    function swapX2YCallback(uint256 x, uint256 y, bytes calldata data) external {
        console2.log("=========SWAP RES=========");
        console2.log(x);
        console2.log(y);
        _swap(x, y, true);
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
    string toFile = "src/izumi/to1.txt";
    string toFile2 = "src/izumi/to2.txt";

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
        new iZiSwapFactory(address(this), swapX2YModule, swapY2XModule, liquidity, limitOrder, flashModule, uint24(50));

        pool = iZiSwapPool(factory.newPool(address(tokenA), address(tokenB), uint24(2000), int24(-202990)));
        minter = new Minter(tokenA, tokenB, pool);
        order = new Order(tokenA, tokenB, pool);
        swapper = new Swapper(tokenA, tokenB, pool);
    }

    function test_set() public {
        int24 tickA;
        int24 tickB;
        int128 deltaL;
        int128 carryL = 0;
        tickA = int24(vm.parseInt(vm.readLine(toFile)));
        for (uint256 i = 0; i < 40; i++) {
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
        for (uint256 i = 0; i < 1; i++) {
            tickA = int24(vm.parseInt(vm.readLine(toFile2)));
            uint128 sellingX = uint128(vm.parseUint(vm.readLine(toFile2)));
            uint128 sellingY = uint128(vm.parseUint(vm.readLine(toFile2)));
            order.addLimitOrderY(tickA, sellingY);
            order.addLimitOrderX(tickA, sellingX);
        }

        //  (, int128 liquidityNet,,,) = pool.points(int24(-262480));
        // console2.log(int256(liquidityNet));
        (uint160 sqrtP, int24 currT,,,,, uint128 liquidity, uint128 liquidityX) = pool.state();
        console2.log(sqrtP);
        console2.log(currT);
        console2.log(liquidity);
        console2.log(liquidityX);
        State memory s = State(
            uint160(3099046684502399095391332),
            int24(-202990),
            uint16(0),
            1,
            1,
            false,
            uint128(291533420),
            uint128(56287763)
        );
        pool.setState(s);
        // swapper.swapX2Y();
        swapper.swapY2X();
        console2.log(tokenB.balanceOf(address(swapper)));
    }

    function _test_compare() public {
        vm.createSelectFork(vm.envString("ARBI_RPC_URL"), 140182989);
        address WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        deal(WETH, address(this), 1 ether);

        // IZumi pool = IZumi(0x9C1630da3d6c9d5eF977500478E330b0a56B2f23);
        iZiSwapPool pool = iZiSwapPool(0x6336e3F52d196b4f63eE512455237c934B3355eB);
        pool.swapX2Y(address(this), 0.1 ether, int24(-887272) / 40 * 40, "");
        console2.log(IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8).balanceOf(address(this)));
    }

    function test_compare2() public {
        vm.createSelectFork(vm.envString("ARBI_RPC_URL"), 140182989);
        address USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
        deal(USDC, address(this), 100e6);

        // IZumi pool = IZumi(0x9C1630da3d6c9d5eF977500478E330b0a56B2f23);
        iZiSwapPool pool = iZiSwapPool(0x6336e3F52d196b4f63eE512455237c934B3355eB);
        pool.swapY2X(address(this), 100e6, int24(887272) / 40 * 40, "");
        console2.log(IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8).balanceOf(address(this)));
    }

    function swapX2YCallback(uint256 x, uint256 y, bytes calldata data) external {
        console2.log("=========SWAP RES=========");
        console2.log(x);
        console2.log(y);
        address WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        IERC20(WETH).transfer(msg.sender, x);
    }
    function swapY2XCallback(uint256 x, uint256 y, bytes calldata data) external {
        console2.log("=========SWAP RES=========");
        console2.log(x);
        console2.log(y);
        address USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
        IERC20(USDC).transfer(msg.sender, y);
    }
    

    function _test_preset() public {
        // vm.createSelectFork(vm.envString("ARBI_RPC_URL"), 126909242);
        // vm.createSelectFork(vm.envString("OP_RPC_URL"), 109502000);
        vm.createSelectFork(vm.envString("ARBI_RPC_URL"), 140182989);

        // IZumi pool = IZumi(0x9C1630da3d6c9d5eF977500478E330b0a56B2f23);
        iZiSwapPool pool = iZiSwapPool(0x6336e3F52d196b4f63eE512455237c934B3355eB);
        int24 tickSpacing = pool.pointDelta();

        int24 leftMost = -887272 / tickSpacing / int24(256) - 2;
        int24 rightMost = 887272 / tickSpacing / int24(256) + 1;

        int24 right = leftMost + 1;
        uint256 index;
        uint256 index2;

        while (right < rightMost) {
            uint256 res = pool.pointBitmap(int16(right));
            if (res > 0) {
                for (uint256 i = 0; i < 256; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int256 tick = int256((256 * right + int256(i)) * tickSpacing);
                        int24 orderOrEndpoint = pool.orderOrEndpoint(int24(tick) / tickSpacing);
                        if (orderOrEndpoint & 0x01 == 0x01) {
                            (, int128 liquidityNet,,,) = pool.points(int24(tick));
                            vm.writeLine(toFile, vm.toString(tick));
                            vm.writeLine(toFile, vm.toString(liquidityNet));
                            index++;
                        }
                        if (orderOrEndpoint & 0x02 == 0x02) {
                            (uint128 sellingX,,,,, uint128 sellingY,,,,) = pool.limitOrderData(int24(tick));
                            vm.writeLine(toFile2, vm.toString(tick));
                            vm.writeLine(toFile2, vm.toString(sellingX));
                            vm.writeLine(toFile2, vm.toString(sellingY));
                            index2++;
                        }
                    }

                    res = res >> 1;
                }
            }

            right++;
        }
        vm.writeLine(toFile, vm.toString(index));
        (, int24 currTick,,,,,,) = pool.state();
        vm.writeLine(toFile, vm.toString(currTick));
        vm.writeLine(toFile2, vm.toString(index2));
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

    function _test_2() public {
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
