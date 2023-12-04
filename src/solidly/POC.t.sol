// 1. pool地址
// 2. pool拿到tick
// 3. 开始计算: swap tick deltaL, amountIn, amountOut, sqrtP
// step by step swap
import "forge-std/console2.sol";
import "forge-std/test.sol";
import "./factory/RamsesV2Factory/contracts/V2/RamsesV2Pool.sol";
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
// address: https://arbiscan.io/address/0x562d29b54d2c57F8620C920415C4dCEAdD6dE2d2
// deltaL: 0x000000000000000000000000000000000000000000000000003c198be70ceb4b00000000000000000000000000000001ffffffffffffffffffc3d6cde38ee52700000000000000000000000000000014ffffffffffffffffffffffff8c6305d0000000000000000000000000000d89a0fffffffffffffffffffffffffffe7964ffffffffffffffffffffffffffffffff000000000000000000000fa635642f8effffffffffffffffffffffffffffffec000000000000000000000000739cfa30fffffffffffffffffffffffffff276600000000000000000000000000001869c
contract Deployer is Test {
    function deploy() public returns (TokenA tokenA, TokenB tokenB, RamsesV2Pool pool) {
        tokenA = new TokenA();
        tokenB = new TokenB();
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

    }
}
