// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/console2.sol";
import "forge-std/test.sol";
import "../quote/quote.sol";

contract SolidlyTest is Test {
    QueryData query;
    address pool = 0x51ADfd3244c0c18D064842F99C0be3AC952725c0;

    function setUp() public {}

    function test_1() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 18532784);
        query = new QueryData();
        console2.logBytes(query.queryUniv3TicksSuperCompact(pool, 100));
    }

    function test_2() public {
        vm.createSelectFork(vm.envString("ARBI_RPC_URL"), 148622378);
        query = new QueryData();
        console2.logBytes(query.queryUniv3TicksSuperCompact(0xE7C1A88DF07259b626566ddF9f27EC101361245f, 10));
    }
}
