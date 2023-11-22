pragma solidity 0.8.19;

import "./contracts/CrocSwapDex.sol";

import "forge-std/console2.sol";
import "forge-std/test.sol";

contract QueryCroc is Test {
    using CurveMath for CurveMath.CurveState;
    using CurveRoll for CurveMath.CurveState;
    using SwapCurve for CurveMath.CurveState;
    using SafeCast for uint144;
    using TickMath for uint128;
    using LiquidityMath for uint128;
    using Chaining for Chaining.PairFlow;
    using Bitmaps for uint256;
    using Bitmaps for int24;

    CrocSwapDex public immutable dex;

    constructor(address _dex) {
        dex = CrocSwapDex(payable(_dex));
    }

    function _readSlot(uint256 slot) internal view returns (uint256) {
        return dex.readSlot(slot);
    }

    function _readSlot(bytes32 slot) internal view returns (uint256) {
        return _readSlot(uint256(slot));
    }

    struct QueryInfo {
        bytes32 poolIdx;
        uint8 lobbyBit;
        bool isUpper;
        uint128 priceRoot;
        int24 currTick;
        uint256 index;
        uint256 right;
        int24 bumpTick;
        bool spillsOver;
        int24 liqTick;
        bytes res;
    }

    function queryAmbientTicksSuperCompact(address base, address quote, uint256 len)
        public
        view
        returns (bytes memory)
    {
        QueryInfo memory info;
        if (base > quote) {
            (base, quote) = (quote, base);
        }
        info.poolIdx = keccak256(abi.encode(base, quote, 420));
        info.priceRoot = uint128(_readSlot(keccak256(abi.encode(info.poolIdx, CrocSlots.CURVE_MAP_SLOT))));
        int24 currTick = info.priceRoot.getTickAtSqrtRatio();
        console2.log("slot0.currTick", int256(currTick));
        // upper
        info.isUpper = true;
        info.index = 0;
        info.currTick = currTick;
        while (info.index < len / 2 && info.currTick <= TickMath.MAX_TICK) {
            (info.bumpTick, info.spillsOver) = pinBitmap(info.poolIdx, info.isUpper, info.currTick);
            if (info.spillsOver) {
                info.liqTick = seekMezzSpill(info.poolIdx, info.bumpTick, info.isUpper);
                bool tightSpill = (info.bumpTick == info.liqTick);
                info.bumpTick = info.liqTick;
                if (!tightSpill) {}
            }
            info.currTick = adjTickLiq(info.bumpTick, info.poolIdx, info);
        }
        info.isUpper = false;
        info.currTick = currTick;
        while (info.index < len && info.currTick >= TickMath.MIN_TICK) {
            (info.bumpTick, info.spillsOver) = pinBitmap(info.poolIdx, info.isUpper, info.currTick);
            if (info.spillsOver) {
                info.liqTick = seekMezzSpill(info.poolIdx, info.bumpTick, info.isUpper);
                bool tightSpill = (info.bumpTick == info.liqTick);
                info.bumpTick = info.liqTick;
                if (!tightSpill) {}
            }
            info.currTick = adjTickLiq(info.bumpTick, info.poolIdx, info);
        }

        return info.res;
    }

    function adjTickLiq(int24 bumpTick, bytes32 poolHash, QueryInfo memory info) internal view returns (int24) {
        if (!Bitmaps.isTickFinite(bumpTick)) return bumpTick;
        (uint96 bidLots, uint96 askLots) = queryLevel(poolHash, bumpTick);
        int128 crossDelta = LiquidityMath.netLotsOnLiquidity(bidLots, askLots);
        console2.log("crossDelta", int256(crossDelta));
        if (crossDelta != 0) {
            int256 data = int256(uint256(int256(info.bumpTick)) << 128)
                + (int256(crossDelta) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
            info.res = bytes.concat(info.res, bytes32(uint256(data)));
            info.index++;
        }

        return info.isUpper ? bumpTick : bumpTick - 1;
    }

    function pinBitmap(bytes32 poolHash, bool isUpper, int24 startTick)
        public
        view
        returns (int24 boundTick, bool isSpill)
    {
        console2.log("startTick", int256(startTick));
        console2.log("isUpper", isUpper);
        uint256 termBitmap = queryTerminus(encodeTerm(poolHash, startTick));
        uint16 shiftTerm = startTick.termBump(isUpper);
        int16 tickMezz = startTick.mezzKey();
        console2.log("shiftTerm", uint256(shiftTerm));
        console2.log("tickMezz", int256(tickMezz));
        (boundTick, isSpill) = pinTermMezz(isUpper, shiftTerm, tickMezz, termBitmap);
    }

    function pinTermMezz(bool isUpper, uint16 shiftTerm, int16 tickMezz, uint256 termBitmap)
        public
        pure
        returns (int24 nextTick, bool spillBit)
    {
        (uint8 nextTerm, bool spillTrunc) = termBitmap.bitAfterTrunc(shiftTerm, isUpper);
        console2.log("nextTerm", uint256(nextTerm));
        console2.log("spillTrunc", spillTrunc);
        spillBit = doesSpillBit(isUpper, spillTrunc, termBitmap);
        console2.log("spillBit", spillBit);
        nextTick = spillBit ? spillOverPin(isUpper, tickMezz) : Bitmaps.weldMezzTerm(tickMezz, nextTerm);
        console2.log("nextTick", nextTick);
    }

    function spillOverPin(bool isUpper, int16 tickMezz) public pure returns (int24) {
        if (isUpper) {
            return tickMezz == Bitmaps.zeroMezz(isUpper)
                ? Bitmaps.zeroTick(isUpper)
                : Bitmaps.weldMezzTerm(tickMezz + 1, Bitmaps.zeroTerm(!isUpper));
        } else {
            return Bitmaps.weldMezzTerm(tickMezz, 0);
        }
    }

    function doesSpillBit(bool isUpper, bool spillTrunc, uint256 termBitmap) public pure returns (bool spillBit) {
        if (isUpper) {
            spillBit = spillTrunc;
        } else {
            bool bumpAtFloor = termBitmap.isBitSet(0);
            spillBit = bumpAtFloor ? false : spillTrunc;
        }
    }

    function seekMezzSpill(bytes32 poolIdx, int24 borderTick, bool isUpper) internal view returns (int24) {
        (uint8 lobbyBorder, uint8 mezzBorder) = rootsForBorder(borderTick, isUpper);

        // Most common case is that the next neighboring bitmap on the border has
        // an active tick. So first check here to save gas in the hotpath.
        (int24 pin, bool spills) = seekAtTerm(poolIdx, lobbyBorder, mezzBorder, isUpper);
        if (!spills) return pin;

        // Next check to see if we can find a neighbor in the mezzanine. This almost
        // always happens except for very sparse pools.
        (pin, spills) = seekAtMezz(poolIdx, lobbyBorder, mezzBorder, isUpper);
        if (!spills) return pin;

        // Finally iterate through the lobby layer.
        return seekOverLobby(poolIdx, lobbyBorder, isUpper);
    }

    function seekOverLobby(bytes32 poolIdx, uint8 lobbyBit, bool isUpper) public view returns (int24) {
        return isUpper ? seekLobbyUp(poolIdx, lobbyBit) : seekLobbyDown(poolIdx, lobbyBit);
    }

    function seekLobbyUp(bytes32 poolIdx, uint8 lobbyBit) public view returns (int24) {
        uint8 MAX_MEZZ = 0;
        unchecked {
            // Because it's unchecked idx will wrap around to 0 when it checks all bits
            for (uint8 i = lobbyBit + 1; i > 0; ++i) {
                (int24 tick, bool spills) = seekAtMezz(poolIdx, i, MAX_MEZZ, true);
                if (!spills) return tick;
            }
        }
        return Bitmaps.zeroTick(true);
    }

    function seekLobbyDown(bytes32 poolIdx, uint8 lobbyBit) public view returns (int24) {
        uint8 MIN_MEZZ = 255;
        unchecked {
            // Because it's unchecked idx will wrap around to 255 when it checks all bits
            for (uint8 i = lobbyBit - 1; i < 255; --i) {
                (int24 tick, bool spills) = seekAtMezz(poolIdx, i, MIN_MEZZ, false);
                if (!spills) return tick;
            }
        }
        return Bitmaps.zeroTick(false);
    }

    function seekAtMezz(bytes32 poolIdx, uint8 lobbyBit, uint8 mezzBorder, bool isUpper)
        public
        view
        returns (int24, bool)
    {
        uint256 neighborMezz = queryMezz(encodeMezzWord(poolIdx, lobbyBit));
        uint8 mezzShift = Bitmaps.bitRelate(mezzBorder, isUpper);
        (uint8 mezzBit, bool spills) = neighborMezz.bitAfterTrunc(mezzShift, isUpper);
        if (spills) return (0, true);
        return seekAtTerm(poolIdx, lobbyBit, mezzBit, isUpper);
    }

    function seekAtTerm(bytes32 poolIdx, uint8 lobbyBit, uint8 mezzBit, bool isUpper)
        public
        view
        returns (int24, bool)
    {
        uint256 neighborBitmap = queryTerminus(encodeTermWord(poolIdx, lobbyBit, mezzBit));
        (uint8 termBit, bool spills) = neighborBitmap.bitAfterTrunc(0, isUpper);
        if (spills) return (0, true);
        return (Bitmaps.weldLobbyPosMezzTerm(lobbyBit, mezzBit, termBit), false);
    }

    function queryMezz(bytes32 key) public view returns (uint256) {
        uint256 MEZZ_SLOT = 65542;
        bytes32 slot = keccak256(abi.encode(key, MEZZ_SLOT));
        uint256 res = _readSlot(slot);
        console2.log("query Mezz", res);
        return res;
    }

    function queryTerminus(bytes32 key) public view returns (uint256) {
        uint256 TERMINUS_SLOT = 65543;
        bytes32 slot = keccak256(abi.encode(key, TERMINUS_SLOT));
        uint256 res = _readSlot(slot);
        console2.log("query Terminus", res);
        return res;
    }

    function queryLevel(bytes32 poolHash, int24 tick) public view returns (uint96 bidLots, uint96 askLots) {
        bytes32 key = keccak256(abi.encodePacked(poolHash, tick));
        bytes32 slot = keccak256(abi.encode(key, CrocSlots.LVL_MAP_SLOT));
        uint256 val = _readSlot(slot);

        askLots = uint96((val << 64) >> 160);
        bidLots = uint96((val << 160) >> 160);
        console2.log("query level tick", int256(tick));

        console2.log("query level val", val);
    }

    function encodeTermWord(bytes32 poolIdx, uint8 lobbyPos, uint8 mezzPos) public pure returns (bytes32) {
        int16 mezzIdx = Bitmaps.weldLobbyMezz(Bitmaps.uncastBitmapIndex(lobbyPos), mezzPos);
        return keccak256(abi.encodePacked(poolIdx, mezzIdx));
    }

    function encodeMezzWord(bytes32 poolIdx, uint8 lobbyPos) public pure returns (bytes32) {
        return encodeMezzWord(poolIdx, Bitmaps.uncastBitmapIndex(lobbyPos));
    }

    function encodeMezzWord(bytes32 poolIdx, int8 lobbyPos) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(poolIdx, lobbyPos));
    }

    function encodeTerm(bytes32 poolIdx, int24 tick) public pure returns (bytes32) {
        int16 wordPos = tick.mezzKey();
        return keccak256(abi.encodePacked(poolIdx, wordPos));
    }

    function encodeMezz(bytes32 poolIdx, int24 tick) public pure returns (bytes32) {
        int8 wordPos = tick.lobbyKey();
        return keccak256(abi.encodePacked(poolIdx, wordPos));
    }

    function rootsForBorder(int24 borderTick, bool isUpper) public pure returns (uint8 lobbyBit, uint8 mezzBit) {
        int24 pinTick = isUpper ? borderTick : (borderTick - 1);
        lobbyBit = pinTick.lobbyBit();
        mezzBit = pinTick.mezzBit();
    }
}

contract POC is Test {
    CrocSwapDex dex = CrocSwapDex(payable(0xAaAaAAAaA24eEeb8d57D431224f73832bC34f688));
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    QueryCroc query;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 18618563);
        query = new QueryCroc(address(dex));
    }

    function test_1() public {
        bytes memory res = query.queryAmbientTicksSuperCompact(DAI, USDC, 10);
        uint256 len;
        uint256 first;
        assembly {
            len := mload(res)
            first := add(res, 32)
        }
        for (uint256 i = 0; i < len / 32; i++) {
            int256 tick;
            int256 deltaL;
            assembly {
                let data := mload(first)
                tick := shr(128, data)
                deltaL := shr(128, shl(128, data))
                first := add(first, 32)
            }
            console2.log("tick", tick);
            console2.log("deltaL", deltaL);
        }
    }
}
