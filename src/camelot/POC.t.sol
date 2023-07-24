pragma solidity ^0.8.0;

import "forge-std/test.sol";
import "forge-std/console2.sol";
import "@Algebra/contracts/AlgebraFactory.sol";
import "@Algebra/contracts/AlgebraPoolDeployer.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// contract CamelotTest is Test {
//     address pool = 0xb7Dd20F3FBF4dB42Fd85C839ac0241D09F72955f;
//     int16 internal constant SECOND_LAYER_OFFSET = 3466;
//     uint256 root;
//     mapping(int16 => uint256) tickSecondLayer;

//     function setUp() public {
//         vm.createSelectFork(vm.envString("ARBI_RPC_URL"), 113406591);
//         root = uint256(vm.load(pool, bytes32(uint256(12))));
//         getTickSecondLayer();
//     }

//     function test_1() public {
//         for (int16 i = 0; i < 256; i++) {
//             uint256 index = root & 0x01;
//             root = root >> 1;
//             if (index != 0) {
//                 console2.log("i: ", i);
//                 console2.logBytes32(bytes32(tickSecondLayer[i]));
//                 int256 index2 = tickSecondLayer[i];
//                 uint256 value2 = IPool(pool).tickTable(index2);
//                 for (int16 j = 0; j < 256; j++) {
//                     uint256 index3 = value2 & 0x01;
//                     if (index3 != 0) {
//                         int24 tick = int24(0);
//                     }
//                 }
//             }
//         }
//     }

//     function getTickSecondLayer() internal {
//         for (int16 i = 0; i < 28; i++) {
//             bytes32 slot = keccak256(abi.encode(i, uint256(13)));
//             uint256 value = uint256(vm.load(pool, slot));
//             tickSecondLayer[i] = value;
//         }
//     }
// }
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
        factory = new AlgebraFactory(0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9);
        deployer = new AlgebraPoolDeployer(address(factory), address(1));
        pool = AlgebraPool(factory.createPool(address(tokenA), address(tokenB)));
        pool.initialize(uint160(1 << 96));
        minter = new Minter(tokenA, tokenB, pool);
    }

    function test_1() public {
        pool.tickSpacing();
        minter.mint();
        pool.tickTreeRoot();
        pool.ticks(int24(-600));
        pool.ticks(int24(120));
        pool.tickTable(int16(-600 / int16(256)) - 1);
        pool.tickTable(int16(120 / int16(256)));
        pool.tickSecondLayer(int16(-600 / int16(256) - 1 + 3466) / 256);
        pool.tickSecondLayer(int16(120 / int16(256) - 1 + 3466) / 256);
    }
}
