pragma solidity 0.8.17;

import "forge-std/console2.sol";
import "forge-std/test.sol";

import "./MavrickQuoter.sol";

contract Deploy is Test {
    MavrickQuoter query;
    address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

    function run() public {
        // require(deployer == 0x358506b4C5c441873AdE429c5A2BE777578E2C6f, "wrong deployer! change the private key");
        // require(deployer == 0x399EfA78cAcD7784751CD9FBf2523eDf9EFDf6Ad, "wrong deployer! change the private key");
        // linea
        // vm.createSelectFork(vm.envString("LINEA_RPC_URL"));
        // vm.startBroadcast(deployer);
        // require(block.chainid == 59144, "must be linea");
        // query = new MavrickQuoter();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        // polygon-zkevm
        // vm.createSelectFork("https://zkevm-rpc.com");
        // vm.startBroadcast(deployer);
        // require(block.chainid == 1101, "must be polygon-zkevm");
        // query = new MavrickQuoter();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        // vm.createSelectFork("https://rpc.mantle.xyz");
        // vm.startBroadcast(deployer);
        // require(block.chainid == 5000, "must be mantle");
        // query = new MavrickQuoter();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        // vm.createSelectFork("https://polygon-mainnet.g.alchemy.com/v2/demo");
        // vm.startBroadcast(deployer);
        // require(block.chainid == 137, "must be polygon");
        // query = new MavrickQuoter();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        // vm.createSelectFork("https://eth.llamarpc.com");
        // vm.startBroadcast(deployer);
        // require(block.chainid == 1, "must be etherum");
        // query = new MavrickQuoter();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        // vm.createSelectFork("https://arb-mainnet-public.unifra.io");
        // vm.startBroadcast(deployer);
        // require(block.chainid == 42161, "must be arbi");
        // query = new MavrickQuoter();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        // vm.createSelectFork("https://rpc.notadegen.com/base");
        // vm.startBroadcast(deployer);
        // require(block.chainid == 8453, "must be base");
        // query = new MavrickQuoter();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
        vm.createSelectFork("https://binance.llamarpc.com");
        vm.startBroadcast(deployer);
        require(block.chainid == 56, "must be bsc");
        query = new MavrickQuoter();
        console2.log("query address", address(query));
        vm.stopBroadcast();
        // vm.createSelectFork("https://optimism.blockpi.network/v1/rpc/public");
        // vm.startBroadcast(deployer);
        // require(block.chainid == 10, "must be op");
        // query = new MavrickQuoter();
        // console2.log("query address", address(query));
        // vm.stopBroadcast();
    }
}

contract MavQuoterTest is Test {
    function test_2() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        address pool = 0x2Df64ac2e8874C43021675eD7a65d3429E30b96B;
        MavrickQuoter quoter = new MavrickQuoter();
        quoter.queryMavTicksSuperCompact(pool, 100);
    }

    function _test_compare() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 18218074);
        address pool = 0x2Df64ac2e8874C43021675eD7a65d3429E30b96B;
        0x9980ce3b5570e41324904f46A06cE7B466925E23.staticcall(
            abi.encodeWithSignature("tickLiquidity(address,int32)", pool, int32(0))
        );
    }
}
