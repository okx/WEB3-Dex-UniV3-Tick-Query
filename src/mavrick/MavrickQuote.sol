pragma solidity 0.8.17;

import "forge-std/console2.sol";
import "forge-std/test.sol";

interface IMaverick {
    struct BinInfo {
        uint128 id;
        uint8 kind;
        int32 lowerTick;
        uint128 reserveA;
        uint128 reserveB;
        uint128 mergeId;
    }

    struct BinState {
        uint128 reserveA;
        uint128 reserveB;
        uint128 mergeBinBalance;
        uint128 mergeId;
        uint128 totalSupply;
        uint8 kind;
        int32 lowerTick;
    }

    struct State {
        int32 activeTick;
        uint8 status;
        uint128 binCounter;
        uint64 protocolFeeRatio;
    }

    function tickSpacing() external view returns (uint256);
    function binMap(int32 tick) external view returns (uint256);
    function binPositions(int32 tick, uint256 kind) external view returns (uint128);
    function getState() external view returns (State memory);
    function getBin(uint128 binId) external view returns (BinState memory bin);
}

contract MavQuoter {
    /**
     * 算法逻辑  
     * 1. 获取当前活跃的tick pool.getState
     * 2. 根据currTick计算当前tick所在的word, 即currTick * 4 / 256, 如果currTick < 0, 则word--
     * 3. 根据currTick计算当前tick的index, 即currTick * 4 % 256
     */

    function quote(address pool, uint256 len) external view returns (bytes memory) {
        IMaverick.State memory state = IMaverick(pool).getState();
        int32 activeTick = state.activeTick;
        int32 word = activeTick * 4 / 256;
        int32 index = activeTick * 4 % 256;
        console2.log(activeTick);
        console2.log(word);
        console2.log(index);
        console2.log((256 * word + index) / 4);

        // int32 leftMost = -887272 * 4 / int32(256) - 2;
        int32 leftMost = int32(0);
        // int32 rightMost = 887272 * 4 / int32(256) + 1;
        int32 rightMost = int32(10);
        while (leftMost < rightMost) {
            uint256 res = IMaverick(pool).binMap(leftMost);
            if (res != 0) {
                for (int32 i = 0; i < 256; i++) {
                    bool isInit = res & 0x01 > 0;
                    if (!isInit) continue;
                    int32 tick = (leftMost * 256 + i) / 4;
                    console2.log(tick);
                    int32 kind = (leftMost * 256 + i) % 4;
                    console2.log(kind);
                    uint128 binNum = IMaverick(pool).binPositions(tick, uint256(int256(kind)));
                    if (binNum != 0) {
                        IMaverick.BinState memory binState = IMaverick(pool).getBin(binNum);
                        console2.log("=======");
                        console2.log(binState.lowerTick);
                        console2.log(binState.kind);
                        // console2.log(
                        //     bin.lowerTick,
                        //     bin.kind,
                        //     bin.reserveA,
                        //     bin.reserveB
                        // );
                    }
                    res = res >> 1;
                }
            }
            leftMost++;
        }
    }
}

contract MavQuoterTest is Test {
    function test_quote() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 18218074);
        address pool = 0x2Df64ac2e8874C43021675eD7a65d3429E30b96B;
        MavQuoter quoter = new MavQuoter();
        quoter.quote(pool, 10);
    }

    function test_compare() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 18218074);
        address pool = 0x2Df64ac2e8874C43021675eD7a65d3429E30b96B;
        0x9980ce3b5570e41324904f46A06cE7B466925E23.staticcall(
            abi.encodeWithSignature("tickLiquidity(address,int32)", pool, int32(0))
        );
    }
}
