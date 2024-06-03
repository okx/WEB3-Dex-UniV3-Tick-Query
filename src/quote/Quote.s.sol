pragma solidity 0.8.17;

import "forge-std/test.sol";
import "forge-std/console2.sol";
import "./quote.sol";
import "../ambient/contracts/libraries/TickMath.sol";

contract Deploy is Test {
    QueryData query;
    address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

    function run() public {
        // require(deployer == 0x358506b4C5c441873AdE429c5A2BE777578E2C6f, "wrong deployer! change the private key");
        // require(deployer == 0x399EfA78cAcD7784751CD9FBf2523eDf9EFDf6Ad, "wrong deployer! change the private key");
        // linea
        // vm.createSelectFork(vm.envString("LINEA_RPC_URL"));
        // vm.startBroadcast(deployer);
        // require(block.chainid == 59144, "must be linea");
        // query = new QueryData();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        // polygon-zkevm
        // vm.createSelectFork("https://zkevm-rpc.com");
        // vm.startBroadcast(deployer);
        // require(block.chainid == 1101, "must be polygon-zkevm");
        // query = new QueryData();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        // vm.createSelectFork("https://rpc.mantle.xyz");
        // vm.startBroadcast(deployer);
        // require(block.chainid == 5000, "must be mantle");
        // query = new QueryData();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        // vm.createSelectFork("https://polygon.blockpi.network/v1/rpc/public");
        // vm.startBroadcast(deployer);
        // require(block.chainid == 137, "must be polygon");
        // query = new QueryData();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        // vm.createSelectFork("https://eth.llamarpc.com");
        // vm.startBroadcast(deployer);
        // require(block.chainid == 1, "must be etherum");
        // query = new QueryData();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        // vm.createSelectFork("https://rpc.arb1.arbitrum.gateway.fm");
        // vm.startBroadcast(deployer);
        // require(block.chainid == 42161, "must be arbi");
        // query = new QueryData();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        // vm.createSelectFork("https://rpc.notadegen.com/base");
        // vm.startBroadcast(deployer);
        // require(block.chainid == 8453, "must be base");
        // query = new QueryData();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        // vm.createSelectFork("https://binance.llamarpc.com");
        // vm.startBroadcast(deployer);
        // require(block.chainid == 56, "must be bsc");
        // query = new QueryData();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        // vm.createSelectFork("https://optimism.blockpi.network/v1/rpc/public");
        // vm.startBroadcast(deployer);
        // require(block.chainid == 10, "must be op");
        // query = new QueryData();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        // vm.createSelectFork(vm.envString("SCROLL_RPC_URL"));
        // vm.startBroadcast(deployer);
        // require(block.chainid == 534352, "must be scroll");
        // query = new QueryData();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        // vm.createSelectFork(vm.envString("FTM_RPC_URL"));
        // vm.startBroadcast(deployer);
        // require(block.chainid == 250, "must be FTM");
        // query = new QueryData();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        // vm.createSelectFork("https://pacific-rpc.manta.network/http");
        // vm.startBroadcast(deployer);
        // require(block.chainid == 169, "must be manta");
        // query = new QueryData();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        // vm.createSelectFork("https://mainnet.mode.network");
        // vm.startBroadcast(deployer);
        // require(block.chainid == 34443, "must be mode");
        // query = new QueryData();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        vm.createSelectFork("https://xlayerrpc.okx.com/");
        vm.startBroadcast(deployer);
        // require(block.chainid == 34443, "must be mode");
        query = new QueryData();
        console2.log("query address", address(query));
        vm.stopBroadcast();
    }
}

contract UniV3QuoteTest is Test {
    IUniswapV3Pool WETH_USDC = IUniswapV3Pool(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; //1
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; //0
    QueryData query;

    function setUp() public {}

    function _test_superCompact() public {
        vm.createSelectFork("https://eth-mainnet.g.alchemy.com/v2/7Brn0mxZnlMWbHf0yqAEicmsgKdLJGmA", 17_990_681);
        query = new QueryData();
        (, bytes memory res) = address(WETH_USDC).staticcall(abi.encodeWithSignature("slot0()"));
        int24 curr;
        assembly {
            curr := mload(add(res, 64))
        }
        console2.log(curr);
    }

    function _test_op() public {
        vm.createSelectFork(vm.envString("OP_RPC_URL"), 109_530_240);
        query = new QueryData();
        query.queryUniv3TicksSuperCompact(0x9C1630da3d6c9d5eF977500478E330b0a56B2f23, 100);
    }

    function _test_eth() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 18_182_443);
        query = new QueryData();
        bytes memory tickInfo = QueryData(0xcAB450888f7F25762EB0710f40B67fF76767aB86).queryUniv3TicksSuperCompact(
            0x694D149DF9B0d82C92940aD3b8fa10722114ca71,
            100
        );
        uint256 len;
        uint256 offset;

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

    function _test_compare() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 18_182_443);
        address pool = 0x694D149DF9B0d82C92940aD3b8fa10722114ca71;
        int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();

        int24 leftMost = -887_272 / tickSpacing / int24(256) - 2;
        int24 rightMost = 887_272 / tickSpacing / int24(256) + 1;
        while (leftMost < rightMost) {
            uint256 res = IUniswapV3Pool(pool).tickBitmap(int16(leftMost));
            if (res > 0) {
                for (uint256 i = 0; i < 256; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int256 tick = int256((256 * leftMost + int256(i)) * tickSpacing);
                        (, int128 liquidityNet, , , , , , ) = IUniswapV3Pool(pool).ticks(int24(int256(tick)));
                        console2.log(tick);
                        console2.log(liquidityNet);
                    }

                    res = res >> 1;
                }
            }
            leftMost++;
        }
    }
    // function _test_query1() public {
    //     (int24[] memory ticks, int128[] memory lp) =
    //         query.queryUniv3TicksPool(address(WETH_USDC), int24(69080), int24(414490));
    //     for (uint256 i = 0; i < ticks.length; i++) {
    //         console2.log("tick: %d", ticks[i]);
    //         console2.log("l: %d", lp[i]);
    //     }
    // }

    // function _test_query2() public {
    //     (int24[] memory ticks, int128[] memory lp) =
    //         query.queryUniv3TicksPool3(address(WETH_USDC), int24(-66050), int24(400000), 500);
    //     for (uint256 i = 0; i < ticks.length; i++) {
    //         console2.log("tick: %d", ticks[i]);
    //         console2.log("l: %d", lp[i]);
    //     }
    // }

    // function _test_query3() public {
    //     bytes memory tickInfo = query.queryUniv3TicksPool3Compact(address(WETH_USDC), int24(-66050), int24(400000));
    //     uint256 len;
    //     uint256 offset;
    //     console2.logBytes(tickInfo);

    //     assembly {
    //         len := mload(tickInfo)
    //         offset := add(tickInfo, 32)
    //     }
    //     for (uint256 i = 0; i < len / 32; i++) {
    //         int256 res;
    //         assembly {
    //             res := mload(offset)
    //             offset := add(offset, 32)
    //         }
    //         console2.log("tick: %d", int128(res >> 128));
    //         console2.log("l: %d", int128(res));
    //     }
    // }

    // function _test_query4() public {
    //     bytes memory tickInfo = query.queryUniv3TicksPool3Compact(
    //         address(0xc8fA85920a4cB22d8c6d15E0125F5c76F27a3a73), int24(-887272), int24(887272)
    //     );
    //     uint256 len;
    //     uint256 offset;
    //     console2.logBytes(tickInfo);

    //     assembly {
    //         len := mload(tickInfo)
    //         offset := add(tickInfo, 32)
    //     }
    //     for (uint256 i = 0; i < len / 32; i++) {
    //         int256 res;
    //         assembly {
    //             res := mload(offset)
    //             offset := add(offset, 32)
    //         }
    //         console2.log("tick: %d", int128(res >> 128));
    //         console2.log("l: %d", int128(res));
    //     }
    //     (int24[] memory ticks, int128[] memory lp) = query.queryUniv3TicksPool3(
    //         address(0xc8fA85920a4cB22d8c6d15E0125F5c76F27a3a73), int24(-887272), int24(887272), 500
    //     );
    //     for (uint256 i = 0; i < ticks.length; i++) {
    //         console2.log("tick: %d", ticks[i]);
    //         console2.log("l: %d", lp[i]);
    //     }
    // }

    // function _test_debug() public {
    //     bytes memory data =
    //         hex"fffffffffffffffffffffffffffffc470000000000000000000000000037ff17fffffffffffffffffffffffffffffed800000000000000000000000bca8b57d1ffffffffffffffffffffffffffffff350000000000000000000000000149a91effffffffffffffffffffffffffffff9b00000000000000000000000001213eeaffffffffffffffffffffffffffffff9c0000000000000000000000aef36f6dc1ffffffffffffffffffffffffffffffa20000000000000000000002cebb4ac8e4ffffffffffffffffffffffffffffffcd000000000000000000000035e083fcbdffffffffffffffffffffffffffffffce000000000000000000000cb441bbd645ffffffffffffffffffffffffffffffd2ffffffffffffffffffffffffe819aa89ffffffffffffffffffffffffffffffd700000000000000000000000071cd255cffffffffffffffffffffffffffffffdc000000000000000000002e928c272821ffffffffffffffffffffffffffffffe80000000000000000000000017f30858effffffffffffffffffffffffffffffea000000000000000000001dd3fa592611ffffffffffffffffffffffffffffffeb0000000000000000000000514b13c29fffffffffffffffffffffffffffffffec0000000000000000000027e7cdd1ee03ffffffffffffffffffffffffffffffed000000000000000000000844df620cc9ffffffffffffffffffffffffffffffef000000000000000000000000604c3e6bfffffffffffffffffffffffffffffff0000000000000000000000a545ed07af1fffffffffffffffffffffffffffffff100000000000000000000003bab412a83fffffffffffffffffffffffffffffff1ffffffffffffffffffffffc454bed57dfffffffffffffffffffffffffffffff300000000000000000000642d2ba980b0fffffffffffffffffffffffffffffff400000000000000000000006f21d8b7c8fffffffffffffffffffffffffffffff4ffffffffffffffffffff9bd2d4567f50fffffffffffffffffffffffffffffff600000000000000000000135529c2cbc5fffffffffffffffffffffffffffffff70000000000000000000004a649d068b5fffffffffffffffffffffffffffffff9000000000000000000000002fd3231a1fffffffffffffffffffffffffffffffa000000000000000000000035b26b8e58fffffffffffffffffffffffffffffffb00000000000000000000017d49001373fffffffffffffffffffffffffffffffc000000000000000000150ae126ce4c55fffffffffffffffffffffffffffffffcffffffffffffffffffece969ac72a65ffffffffffffffffffffffffffffffffdffffffffffffffffffff524ac7a7615afffffffffffffffffffffffffffffffeffffffffffffffffffffc0f6ba0e5d0e00000000000000000000000000000000000000000000000000013312402fc186000000000000000000000000000000010000000000000000000f90595bc79c43000000000000000000000000000000020000000000000000000071d1c8d0d11f00000000000000000000000000000002ffffffffffffffffffffe89503d3b57000000000000000000000000000000003ffffffffffffffffffff2c4d1a746ab500000000000000000000000000000004fffffffffffffffffffffe2f86a7e40e00000000000000000000000000000005ffffffffffffffffffefcd31a4bcaaba00000000000000000000000000000006ffffffffffffffffffffffeced3462db00000000000000000000000000000007ffffffffffffffffffffffcb9c49ae2900000000000000000000000000000008fffffffffffffffffffffff74c7c3bd40000000000000000000000000000000a000000000000000000000cc1132ded6b0000000000000000000000000000000affffffffffffffffffffd16d73d8d7df0000000000000000000000000000000bfffffffffffffffffffffffd02cdce5e0000000000000000000000000000000cfffffffffffffffffffffffeec3c87130000000000000000000000000000000fffffffffffffffffffffc69e240fba7000000000000000000000000000000011ffffffffffffffffffffffff0937d26600000000000000000000000000000012fffffffffffffffffffff668b263b86600000000000000000000000000000013ffffffffffffffffffffd818f52620cb00000000000000000000000000000015fffffffffffffffffffed96193817ebf00000000000000000000000000000016fffffffffffffffffffff5ac97f7b2a900000000000000000000000000000017ffffffffffffffffffffffff9fb3c1950000000000000000000000000000001dffffffffffffffffffffff90de27483800000000000000000000000000000025ffffffffffffffffffffffcb94280f3b00000000000000000000000000000026ffffffffffffffffffffffff8e32daa40000000000000000000000000000002cfffffffffffffffffffff34bd63c59ee00000000000000000000000000000030ffffffffffffffffffffffffe3c34b6d00000000000000000000000000000031ffffffffffffffffffffffffffee254400000000000000000000000000000044ffffffffffffffffffffffffe744737a00000000000000000000000000000062fffffffffffffffffffffffea66f69b100000000000000000000000000000063ffffffffffffffffffffff510c90923f0000000000000000000000000000006dfffffffffffffffffffffd3144b5371c0000000000000000000000000000012ffffffffffffffffffffffff41a87ddc7000000000000000000000000000003b8fffffffffffffffffffffffffeb656e2";
    //     uint256 len;
    //     uint256 offset;
    //     assembly {
    //         len := mload(data)
    //         offset := add(data, 32)
    //     }
    //     for (uint256 i = 0; i < len / 32; i++) {
    //         int256 res;
    //         assembly {
    //             res := mload(offset)
    //             offset := add(offset, 32)
    //         }
    //         console2.log("tick: %d", int128(res >> 128));
    //         console2.log("l: %d", int128(res));
    //     }
    // }

    // function _test_querySupper() public {

    //     (int24[] memory ticks, int128[] memory lp) = query.queryUniv3TicksSuper(address(WETH_USDC), 500);
    //     console2.log("len", ticks.length);
    //     for (uint256 i = 0; i < ticks.length; i++) {
    //         console2.log("tick: %d", ticks[i]);
    //         console2.log("l: %d", lp[i]);
    //     }
    // }

    function _test_querySupper2() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), 3_555_583);
        // query = QueryData(0x627fd455849665685086181Aff520E30F209D34E);
        query = new QueryData();
        bytes memory tickInfo = query.queryUniv3TicksSuperCompact(0x268854Be35C96F08b21c6829e122E859b02DD7C3, 500);
        uint256 len;
        uint256 offset;
        console2.logBytes(tickInfo);

        assembly {
            len := mload(tickInfo)
            offset := add(tickInfo, 32)
        }
        console2.log("len", len);
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

// contract HorizonQuoteTest is Test {
//     IHorizonPool WETH_USDC = IHorizonPool(0x77557405a645c79e9F8b0096997b6a247B12b315);
//     QueryData query;

//     function setUp() public {
//         vm.createSelectFork("https://linea-mainnet.infura.io/v3/4b1ef7929a9b4d789e37917c736673d2", 43253);
//         query = new QueryData();
//     }

//     // function test_query() public {
//     //     bytes memory tickInfo =
//     //         query.queryHorizonTicksPoolCompact(address(WETH_USDC), int24(887273), uint256(10), true);
//     //     uint256 len;
//     //     uint256 offset;

//     //     assembly {
//     //         len := mload(tickInfo)
//     //         offset := add(tickInfo, 32)
//     //     }
//     //     for (uint256 i = 0; i < len / 32; i++) {
//     //         int256 res;
//     //         assembly {
//     //             res := mload(offset)
//     //             offset := add(offset, 32)
//     //         }
//     //         console2.log("tick: %d", int128(res >> 128));
//     //         console2.log("l: %d", int128(res));
//     //     }
//     // }
//     function test_query2() public {
//         bytes memory tickInfo =
//             query.queryHorizonTicksSuperCompact(address(WETH_USDC), 10);
//         uint256 len;
//         uint256 offset;

//         assembly {
//             len := mload(tickInfo)
//             offset := add(tickInfo, 32)
//         }
//         for (uint256 i = 0; i < len / 32; i++) {
//             int256 res;
//             assembly {
//                 res := mload(offset)
//                 offset := add(offset, 32)
//             }
//             console2.log("tick: %d", int128(res >> 128));
//             console2.log("l: %d", int128(res));
//         }
//     }

//     // function test_query2() public {
//     //     (int24[] memory ticks, int128[] memory lps) =
//     //         query.queryHorizonTicksPool(address(WETH_USDC), int24(887273), uint256(10), false);
//     //     for (uint256 i = 0; i < ticks.length; i++) {
//     //         console2.log("tick", ticks[i]);
//     //         console2.log("lps ", lps[i]);
//     //     }
//     // }
// }

contract AlgebraQuoteTest is Test {
    address WETH_USDC = 0xb7Dd20F3FBF4dB42Fd85C839ac0241D09F72955f;
    address WETH_QQ = 0xdAD783421C225e2202afCd236772433F01b57ea4;
    QueryData query;

    function setUp() public {
        // vm.createSelectFork("https://rpc.ankr.com/arbitrum");
        // query = new QueryData();
    }

    function test_query_xlayer() public {
        vm.createSelectFork("https://xlayerrpc.okx.com/");
        query = new QueryData();
        bytes memory tickInfo = query.queryAlgebraTicksSuperCompact4(
            address(0xE47121D706e3Aeb4243f58551023c0849cda88Ce),
            10
        );
        // 0xE47121D706e3Aeb4243f58551023c0849cda88Ce.call(abi.encodeWithSignature("", ));
        // query.queryAlgebraTicksSuperCompact(address(WETH_USDC), 100);
        // query.queryAlgebraTicksPoolCompact(address(WETH_USDC),887273, 100, false);
        uint256 len;
        uint256 offset;
        // console2.logBytes(tickInfo);

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

    function test_xlayer_swap() public {
        vm.createSelectFork("https://xlayerrpc.okx.com/");
        address pool = 0xE47121D706e3Aeb4243f58551023c0849cda88Ce;
        pool.call(
            abi.encodeWithSignature(
                "swap(address,bool,int256,uint160,bytes)",
                address(this),
                true,
                1,
                TickMath.getSqrtRatioAtTick(-887_271),
                ""
            )
        );
    }

    function algebraSwapCallback(int256 amount0, int256 amount1, bytes memory) public {
        if (amount0 > 0) {
            address token = IUniswapV3PoolImmutables(msg.sender).token0();
            deal(token, msg.sender, uint256(amount0));
        }
        if (amount1 > 0) {
            address token = IUniswapV3PoolImmutables(msg.sender).token1();
            deal(token, msg.sender, uint256(amount1));
        }
    }

    function test_query() public {
        // vm.createSelectFork(vm.envString("ARBI_RPC_URL"));
        vm.createSelectFork("https://rpc.arb1.arbitrum.gateway.fm");
        query = new QueryData();
        bytes memory tickInfo = query.queryAlgebraTicksSuperCompact3( // hex"ffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000d000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000fffffffffffffffffffffffffffffff200000000000000000000000000000000ffffffffffffffffffffffffffffffee00000000000000000000000000000000";
                address(0xcc065Eb6460272481216757293FFC54A061bA60e),
                100
            );
        // query.queryAlgebraTicksSuperCompact(address(WETH_USDC), 100);
        // query.queryAlgebraTicksPoolCompact(address(WETH_USDC),887273, 100, false);
        uint256 len;
        uint256 offset;
        // console2.logBytes(tickInfo);

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

    function _test_compare() public {
        address pool = WETH_USDC;

        int24 leftMost = -887_272 / int24(256) - 2;
        int24 rightMost = 887_272 / int24(256) + 1;
        while (leftMost < rightMost) {
            uint256 res = IAlgebraPoolV1_9(pool).tickTable(int16(leftMost));
            if (res > 0) {
                for (uint256 i = 0; i < 256; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int24 tick = int24(int256((256 * leftMost + int256(i)) * 1));
                        IAlgebraPoolV1_9(pool).ticks(tick);
                        console2.log(tick);
                    }

                    res = res >> 1;
                }
            }
            leftMost++;
        }
    }

    // function test_query2() public {
    //     (int24[] memory ticks, int128[] memory lps) =
    //         query.queryAlgebraTicksPool(address(WETH_USDC), int24(887273), uint256(100), false);
    //     for (uint256 i = 0; i < ticks.length; i++) {
    //         console2.log("tick", ticks[i]);
    //         console2.log("lps ", lps[i]);
    //     }
    // }
    // function test_queryBase() public {
    //     vm.createSelectFork("https://base-mainnet.public.blastapi.io", 3553312);
    //     address pool = 0xC2f9C81cd84f04c159c55A68C8EF3ad86f66105C;
    //     query = new QueryData();
    //     console2.log("aaa");
    //     // QueryData query = QueryData(0x7c569c320A8a879C834d09FDB6e3276Ee6f18f41);
    //     // bytes memory tickInfo = query.queryAlgebraTicksSuperCompact(address(pool), 10);
    //     bytes memory tickInfo = hex"00000000000000000000000000000a8cfffffffffffffffffff63c053df3805bfffffffffffffffffffffffffffff48400000000000000000009c3fac20c7fa5";
    //     uint256 len;
    //     uint256 offset;

    //     assembly {
    //         len := mload(tickInfo)
    //         offset := add(tickInfo, 32)
    //     }
    //     for (uint256 i = 0; i < len / 32; i++) {
    //         int256 res;
    //         assembly {
    //             res := mload(offset)
    //             offset := add(offset, 32)
    //         }
    //         console2.log("tick: %d", int128(res >> 128));
    //         console2.log("l: %d", int128(res));
    //     }
    // }
}

contract IZumiQuoteTest is Test {
    address WBNB_USDT = 0x1CE3082de766ebFe1b4dB39f616426631BbB29aC;
    QueryData query;

    function setUp() public {
        // vm.createSelectFork("https://binance.nodereal.io", 31903446);
        query = new QueryData();
    }

    // https://bscscan.com/tx/0x6eb4a00f9b49306ffe079e4807a32b3de42b885a8676c508b246c3c967167564
    function _test_3() public {
        bytes
            memory data = hex"fffbc1480000000000000000000000000000000000000000000000000091dfb3fffbbfb800000000000000000000000000000000000000000000000000989680fffbba4000000000000000000000000000000000000000000000000000989680fffbb40000000000000000000000000000000000000000000000000000989680fffbacf800000000000000000000000000000000000000000000000000989680fffba46000000000000000000000000000000000000000000000000000989680fffb9d58000000000000000000000000000000000000000000000000004c4b40fffb997000000000000000000000000000000000000000000000000000989680fffb890800000000000000000000000000000000000000000000000000989680fffb6e78000000000000000000000000000000000000000000000000001e8480fffb6db00000000000000000000000000000000000000000000000000098967f";
        uint256 len;
        uint256 offset;
        assembly {
            len := div(mload(data), 32)
            offset := add(data, 32)
        }
        for (uint256 i = 0; i < len; i++) {
            int256 res;
            int32 tick;
            uint112 sellingX;
            uint112 sellingY;
            assembly {
                res := mload(offset)
                offset := add(offset, 32)
                tick := and(0xffffffff, shr(224, res))
                sellingX := and(0xffffffffffffffffffffffffffff, shr(112, res))
                sellingY := and(0xffffffffffffffffffffffffffff, res)
            }
            console2.log("tick: %d", tick);
            console2.log("sellingX: %d", sellingX);
            console2.log("sellingY: %d", sellingY);
        }
    }

    function _test_2() public {
        query.queryIzumiSuperCompact(WBNB_USDT, 200);
    }

    function _test_compare() public {
        address pool = WBNB_USDT;
        int24 tickSpacing = IZumiPool(pool).pointDelta();

        int24 leftMost = -887_272 / tickSpacing / int24(256) - 2;
        int24 rightMost = 887_272 / tickSpacing / int24(256) + 1;
        while (leftMost < rightMost) {
            uint256 res = IZumiPool(pool).pointBitmap(int16(leftMost));
            if (res > 0) {
                for (uint256 i = 0; i < 256; i++) {
                    uint256 isInit = res & 0x01;
                    if (isInit > 0) {
                        int24 tick = int24(int256((256 * leftMost + int256(i)) * tickSpacing));
                        int24 orderOrEndpoint = IZumiPool(pool).orderOrEndpoint(tick / tickSpacing);
                        if (orderOrEndpoint & 0x01 == 0x01) {
                            (, int128 liquidityNet, , , ) = IZumiPool(pool).points(tick);
                            console2.log(tick);
                        }
                        // if (orderOrEndpoint & 0x02 == 0x02) {
                        //     (uint128 sellingX,,,,, uint128 sellingY,,,,) = IZumiPool(pool).limitOrderData(tick);
                        //     // console2.log(tick);
                        // }
                    }

                    res = res >> 1;
                }
            }
            leftMost++;
        }
    }
}
