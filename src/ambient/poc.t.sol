pragma solidity 0.8.19;

import "./contracts/CrocSwapDex.sol";
import "forge-std/console2.sol";
import "forge-std/test.sol";

contract POC is Test {
    CrocSwapDex dex = CrocSwapDex(payable(0xAaAaAAAaA24eEeb8d57D431224f73832bC34f688));
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    function setUp() public {
        vm.createSelectFork("mainnet", 18618563);
    }
    function test_getTick() public {
        
    }
}