pragma solidity 0.8.19;

import "forge-std/test.sol";
import "forge-std/console2.sol";
import "./quote.sol";

contract POC is Test {
    IUniswapV3Pool WETH_USDC = IUniswapV3Pool(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; //1
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; //0
    QueryData query;

    function setUp() public {
        vm.createSelectFork("https://eth.llamarpc.com", 12544978 + 1);
        query = new QueryData();
    }

    address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

    function run() public {
        require(deployer == 0x399EfA78cAcD7784751CD9FBf2523eDf9EFDf6Ad, "wrong deployer! change the private key");
        // linea
        vm.createSelectFork(vm.envString("LINEA_RPC_URL"));
        vm.startBroadcast(deployer);
        require(block.chainid == 1, "must be mainnet");
        query = new QueryData();
        console2.log("query address", address(query));
        vm.stopBroadcast();
    }

    function test_query() public {
        (int256[] memory tickInfo) =
            query.queryUniv3TicksPool2(address(WETH_USDC), int24(69080), int24(414490), uint256(10));
        for (uint256 i = 0; i < tickInfo.length; i++) {
            console2.log("tick: %d", int128(tickInfo[i] >> 128));
            console2.log("l: %d", int128(tickInfo[i]));
        }
    }

    function test_query3() public {
        (bytes memory tickInfo) = query.queryUniv3TicksPool3(address(WETH_USDC), int24(-69080), int24(414490));
        uint256 len;
        uint256 offset;
        console2.logBytes(tickInfo);

        assembly {
            len := mload(tickInfo)
            offset := add(tickInfo, 32)
        }
        for (uint256 i = 0; i < len / 32; i++) {
            int256 res;
            assembly {
                res := mload(offset)
                offset := add(offset, 32)
            }
            console2.log("tick: %d", int128(res >> 128));
            console2.log("l: %d", int128(res));
        }
    }
}
