pragma solidity 0.8.19;

import {QueryCroc,LiquidityMath} from "./queryFlatten.sol";

import "forge-std/console2.sol";
import "forge-std/test.sol";


contract POC is Test {
    address dex = 0xAaAaAAAaA24eEeb8d57D431224f73832bC34f688;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    QueryCroc query;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 18618563);
        query = new QueryCroc(address(dex));
    }

    function test_1() public {
        bytes memory res = query.queryAmbientTicksSuperCompact(DAI, USDC, 100);
        bytes32 poolHash = keccak256(abi.encode(DAI, USDC, 420));
        uint256 len;
        uint256 first;
        assembly {
            len := mload(res)
            first := add(res, 32)
        }
        for (uint256 i = 0; i < len / 32; i++) {
            int24 tick;
            int128 deltaL;
            assembly {
                let data := mload(first)
                tick := shr(128, data)
                deltaL := data
                first := add(first, 32)
            }
            console2.log("tick", int256(tick));
            console2.log("deltaL", int256(deltaL));
            (uint96 bidLots, uint96 askLots) = query.queryLevel(poolHash, int24(tick));
            int128 crossDelta = LiquidityMath.netLotsOnLiquidity(bidLots, askLots);
            console2.log("deltaL2", crossDelta);
        }
    }
}

contract Deploy is Test {
    QueryCroc query;
    address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

    function run() public {
        require(deployer == 0x358506b4C5c441873AdE429c5A2BE777578E2C6f, "wrong deployer! change the private key");
        // require(deployer == 0x399EfA78cAcD7784751CD9FBf2523eDf9EFDf6Ad, "wrong deployer! change the private key");

        // vm.startBroadcast(deployer);
        // require(block.chainid == 1, "must be etherum");
        // query = new QueryCroc(0xAaAaAAAaA24eEeb8d57D431224f73832bC34f688);
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        vm.createSelectFork(vm.envString("SCROLL_RPC_URL"));
        vm.startBroadcast(deployer);
        require(block.chainid == 534352, "must be scroll");
        query = new QueryCroc(0xaaaaAAAACB71BF2C8CaE522EA5fa455571A74106);
        console2.log("query address", address(query));
        vm.stopBroadcast();
    }
}