pragma solidity 0.8.19;

/// @title Safe casting methods
/// @notice Contains methods for safely casting between types
library SafeCast {
    /// @notice Cast a uint256 to a uint160, revert on overflow
    /// @param y The uint256 to be downcasted
    /// @return z The downcasted integer, now type uint160
    function toUint160(uint256 y) internal pure returns (uint160 z) {
        unchecked {
            // Explicit bounds check
            require((z = uint160(y)) == y);
        }
    }

    /// @notice Cast a uint256 to a uint128, revert on overflow
    /// @param y The uint256 to be downcasted
    /// @return z The downcasted integer, now type uint128
    function toUint128(uint256 y) internal pure returns (uint128 z) {
        unchecked {
            // Explicit bounds check
            require((z = uint128(y)) == y);
        }
    }

    /// @notice Cast a uint192 to a uint128, revert on overflow
    /// @param y The uint192 to be downcasted
    /// @return z The downcasted integer, now type uint128
    function toUint128By192(uint192 y) internal pure returns (uint128 z) {
        unchecked {
            // Explicit bounds check
            require((z = uint128(y)) == y);
        }
    }

    /// @notice Cast a uint144 to a uint128, revert on overflow
    /// @param y The uint144 to be downcasted
    /// @return z The downcasted integer, now type uint128
    function toUint128By144(uint144 y) internal pure returns (uint128 z) {
        unchecked {
            // Explicit bounds check
            require((z = uint128(y)) == y);
        }
    }

    /// @notice Cast a uint128 to a int128, revert on overflow
    /// @param y The uint128 to be casted
    /// @return z The casted integer, now type int128
    function toInt128Sign(uint128 y) internal pure returns (int128 z) {
        unchecked {
            // Explicit bounds check
            require(y < 2 ** 127);
            return int128(y);
        }
    }

    // Unix timestamp can fit into 32-bits until the year 2106. After which, internally
    // stored timestamps will stop increasing. Deployed contracts relying on this function
    // should be re-evaluated before that date.
    function timeUint32() internal view returns (uint32) {
        unchecked {
            // Explicit bounds check
            uint256 time = block.timestamp;
            if (time > type(uint32).max) return type(uint32).max;
            return uint32(time);
        }
    }
}

/* @title Directive library
 * @notice This library defines common structs and associated helper functions for
 *         user defined trade action directives. */
library Directives {
    using SafeCast for int256;
    using SafeCast for uint256;

    /* @notice Defines a single requested swap on a pre-specified pool.
     *
     * @dev A directive indicating no swap action must set *both* qty and limitPrice to
     *      zero. qty=0 alone will indicate the use of a flexible back-filled rolling 
     *      quantity. 
     *
     * @param isBuy_ If true, swap converts base-side token to quote-side token.
     *               Vice-versa if false.
     * @param inBaseQty_ If true, swap quantity is denominated in base-side token. 
     *                   If false in quote side token.
     * @param rollType_  The flavor of rolling gap fill that should be applied (if any)
     *                   to this leg of the directive. See Chaining.sol for list of
     *                   rolling type codes.
     * @param qty_ The total amount to be swapped. (Or rolling target if rollType_ is 
     *             enabled)
     * @param limitPrice_ The maximum (minimum) *price to pay, if a buy (sell) swap
     *           *at the margin*. I.e. the swap will keep exeucting until the curve
     *           reaches this price (or exhausts the specified quantity.) Represented
     *           as the square root of the pool's price ratio in Q64.64 fixed-point. */
    struct SwapDirective {
        bool isBuy_;
        bool inBaseQty_;
        uint8 rollType_;
        uint128 qty_;
        uint128 limitPrice_;
    }

    /* @notice Defines a sequence of mint/burn actions related to concentrated liquidity
     *         range orders on a single pool.
     *
     * @param lowTick_ A single tick index that defines one side of the range order 
     *                 boundary for all range orders in this directive.
     * @param highTick_ The tick index of the other side of the boundary of the range
     *                  order.
     * @param isAdd_ If true, the action mints new concentrated liquidity. If false, it
     *               burns pre-existing concentrated liquidity. 
     * @param isTickRel_  If true indicates the low and high tick value should be take
     *                    relative to the current price tick. E.g. -5 indicates 5 ticks
     *                    below the current tick. Otherwise, high and low tick values are
     *                    absolute tick index values.
     * @param rollType_  The flavor of rolling gap fill that should be applied (if any)
     *                   to this leg of the directive. See Chaining.sol for list of
     *                   rolling type codes.
     * @param liquidity_ The total amount of concentrated liquidity to add/remove.
     *                   Represented as the equivalent of sqrt(X*Y) liquidity for the 
     *                   equivalent constant-product AMM curve. If rolling is turned
     *                   on, this is instead interpreted as a rolling target value. */
    struct ConcentratedDirective {
        int24 lowTick_;
        int24 highTick_;
        bool isAdd_;
        bool isTickRel_;
        uint8 rollType_;
        uint128 liquidity_;
    }

    /* @notice Along with a root open tick from above defines a single range order mint
     *         or burn action.

    /* @notice Defines a directive related to the mint/burn of ambient liquidity on a 
     *         single pre-specified curve.
     *
     * @dev A directive indicating no ambient mint/burn must set *both* isAdd to false and
     *      liquidity to zero. liquidity=0 alone will indicate the use of a flxeible 
     *      back-filled rolling quantity in place.
     *
     * @param isAdd_ If true, the action mints new ambient liquidity. If false, burns 
     *               pre-existing liquidity in the curve.
     * @param rollType_  The flavor of rolling gap fill that should be applied (if any)
     *                   to this leg of the directive. See Chaining.sol for list of
     *                   rolling type codes.
     * @param liquidity_ The total amount of ambient liquidity to add/remove.
     *                   Represented as the equivalent of sqrt(X*Y) liquidity for a
     *                   constant-product AMM curve. (If this and rollType_ are zero,
     *                   this is a non-action.) */
    struct AmbientDirective {
        bool isAdd_;
        uint8 rollType_;
        uint128 liquidity_;
    }

    /* @param rollExit_ If set to true, use the exit side of the pair's tokens when
     *                  calculating rolling back-fill quantities.
     * @param swapDefer_ If set to true, execute the swap directive *after* the passive
     *                  mint/burn directives for the pool. If false, swap executes first.
     * @param offsetSurplus_ If set to true offset any rolling back-fill quantities with
     *                       the client's pre-existing surplus collateral at the dex. */
    struct ChainingFlags {
        bool rollExit_;
        bool swapDefer_;
        bool offsetSurplus_;
    }

    /* @notice Defines a full suite of trade action directives to be executed on a single
     *         pool within a pre-specified pair.
     * @param poolIdx_ The pool type index that identified the pool to be operated on in
     *                 this pair.
     * @param ambient_ Directive related to ambient liquidity actions (if any).
     * @param conc_ Directives related to concentrated liquidity range orders (if any).
     * @param swap_ Directive for the swap action on the pool (if any).
     * @param chain_ Flags related to chaining order of the directive actions and how
     *               rolling back fill is calculated. */
    struct PoolDirective {
        uint256 poolIdx_;
        AmbientDirective ambient_;
        ConcentratedDirective[] conc_;
        SwapDirective swap_;
        ChainingFlags chain_;
    }

    /* @notice Specifies the settlement procedures between user and dex related to
     *         a single token within a chain of hops in a sequence of one or more
     *         pairs. The same struct is used for the entry/exit terminal tokens as
     *         well as intermediate tokens between pairs.
     *
     * @param token_ The tracker address to the token in the pair. (If set to zero 
     *              specifies native Ethereum as the pair asset.)
     * @param limitQty_ A net flow limit that the user expects the execution to meet
     *    or exceed. Otherwise the transaction is reverted. Negative specifies a minimum
     *    credit from the pool to the user. Positive a maximum debit from user to the 
     *    pool. 
     * @param dustThresh_ A threshold, below which the user requests no transaction is
     *    sent as part of a credit. (Debits are always collected.) Used to avoid 
     *    unnecessary gas cost of a token transfer on an economically meaningless value.
     * @param useSurplus_ If set to true the settlement should attempt to complete using
     *    the client's surplus collateral balance at the dex. */
    struct SettlementChannel {
        address token_;
        int128 limitQty_;
        uint128 dustThresh_;
        bool useSurplus_;
    }

    /* @notice Specified if and how off-grid price improvement is being requested. (Note
     *         that even if requested, there may be no price improvement set for the 
     *         token. To avoid wasted gas, user should check off-chain.)
     * @param isEnabled_ By default, no price improvement is set, avoiding the gas cost
     *         of a storage query. If true, indicates that the user wants to query the
     *         price improvement settings. 
     * @param useBaseSide_ If true requests price improvement from the base-side token
     *         in the pair. Otherwise, requested on the quote-side token. */
    struct PriceImproveReq {
        bool isEnabled_;
        bool useBaseSide_;
    }

    /* @notice Defines a full directive related to a single hop in a sequence of pairs.
     * @param pools_ Defines directives on one or more pools on the pair.
     * @param settle_ Defines the settlement for the token on the *exit* side of the hop.
     *         (The entry side is defined in the previous hop, or the open directive if
     *          this is the first hop in the sequence.)
     * @param improve_ Off-grid price improvement settings. */
    struct HopDirective {
        PoolDirective[] pools_;
        SettlementChannel settle_;
        PriceImproveReq improve_;
    }

    /* @notice Top-level trade order directive, encompassing an arbitrary collection of
     *    of swap, mints, and burns across multiple pools within a chained sequence of 
     *    pairs. 
     * @param open_ Defines the token and settlement for the entry token in the first hop
     *    in the chain.
     * @param hops_ Defines a sequence of directives on pairs that will be executed in the
     *    order specified by this array. */
    struct OrderDirective {
        SettlementChannel open_;
        HopDirective[] hops_;
    }
}

/* @title Order encoding library
 * @notice Provides facilities for encoding and decoding user specified order directive
 *    structures to/from raw transaction bytes. */
library OrderEncoding {
    // Preamble code that begins at the start of long-form orders. Allows us to support
    // alternative message schemas in the future. To start all encoded long-form orders
    // must start with this code in the first character position.
    uint8 constant LONG_FORM_SCHEMA = 1;

    /* @notice Parses raw bytes into an OrderDirective struct in memory.
     * 
     * @dev In general the array lengths and arithmetic in this function and child
     *      functions are unchecked/unsanitized. The only use of this function is to
     *      parse a user-supplied string into constituent commands. If a user supplies
     *      malformed data it will have no impact on the state of the contract besides
     *      the internally safe swap/mint/burn calls. */
    function decodeOrder(bytes calldata input) internal pure returns (Directives.OrderDirective memory dir) {
        uint256 offset = 0;
        uint8 cnt;
        uint8 schemaType;

        (schemaType, dir.open_.token_, dir.open_.limitQty_, dir.open_.dustThresh_, dir.open_.useSurplus_, cnt) =
            abi.decode(input[offset:(offset + 32 * 6)], (uint8, address, int128, uint128, bool, uint8));
        unchecked {
            // 0 + 32*6 is well with bounds of 256 bits
            offset += 32 * 6;
        }

        require(schemaType == LONG_FORM_SCHEMA);

        dir.hops_ = new Directives.HopDirective[](cnt);
        unchecked {
            // An iterate by 1 loop will run out of gas far before overflowing 256 bits
            for (uint256 i = 0; i < cnt; ++i) {
                offset = parseHop(dir.hops_[i], input, offset);
            }
        }
    }

    /* @notice Parses an offset bytestream into a single HopDirective in memory and 
     *         increments the offset accordingly. */
    function parseHop(Directives.HopDirective memory hop, bytes calldata input, uint256 offset)
        private
        pure
        returns (uint256 next)
    {
        next = offset;

        uint8 poolCnt;
        poolCnt = abi.decode(input[next:(next + 32)], (uint8));
        unchecked {
            next += 32;
        }

        hop.pools_ = new Directives.PoolDirective[](poolCnt);
        unchecked {
            // An iterate by 1 loop will run out of gas far before overflowing 256 bits
            for (uint256 i = 0; i < poolCnt; ++i) {
                next = parsePool(hop.pools_[i], input, next);
            }
        }

        return parseSettle(hop, input, next);
    }

    /* @notice Parses the settlement fields in a hop directive. */
    function parseSettle(Directives.HopDirective memory hop, bytes calldata input, uint256 offset)
        private
        pure
        returns (uint256)
    {
        (
            hop.settle_.token_,
            hop.settle_.limitQty_,
            hop.settle_.dustThresh_,
            hop.settle_.useSurplus_,
            hop.improve_.isEnabled_,
            hop.improve_.useBaseSide_
        ) = abi.decode(input[offset:(offset + 32 * 6)], (address, int128, uint128, bool, bool, bool));

        unchecked {
            // Incrementing by 192 will run out of gas far before overflowing 256-bits
            return offset + 32 * 6;
        }
    }

    /* @notice Parses an offset bytestream into a single PoolDirective in memory 
               and increments the offset accordingly. */
    function parsePool(Directives.PoolDirective memory pair, bytes calldata input, uint256 offset)
        private
        pure
        returns (uint256 next)
    {
        uint256 concCnt;
        next = offset;

        (pair.poolIdx_, pair.ambient_.isAdd_, pair.ambient_.rollType_, pair.ambient_.liquidity_, concCnt) =
            abi.decode(input[next:(next + 32 * 5)], (uint256, bool, uint8, uint128, uint8));

        unchecked {
            // Incrementing by 160 will run out of gas far before overflowing 256-bits
            next += 32 * 5;
        }
        pair.conc_ = new Directives.ConcentratedDirective[](concCnt);

        unchecked {
            // An iterate by 1 loop will run out of gas far before overflowing 256 bits
            for (uint256 i = 0; i < concCnt; ++i) {
                next = parseConcentrated(pair.conc_[i], input, next);
            }
        }

        (pair.swap_.isBuy_, pair.swap_.inBaseQty_, pair.swap_.rollType_, pair.swap_.qty_, pair.swap_.limitPrice_) =
            abi.decode(input[next:(next + 32 * 5)], (bool, bool, uint8, uint128, uint128));
        unchecked {
            // Incrementing by 160 will run out of gas far before overlowing 256 bits
            next += 32 * 5;
        }

        (pair.chain_.rollExit_, pair.chain_.swapDefer_, pair.chain_.offsetSurplus_) =
            abi.decode(input[next:(next + 32 * 3)], (bool, bool, bool));
        unchecked {
            // Incrementing by 96 will run out of gas far before overlowing 256 bits
            next += 32 * 3;
        }
    }

    /* @notice Parses an offset bytestream into a single ConcentratedDirective in 
     *         memory and increments the offset accordingly. */
    function parseConcentrated(Directives.ConcentratedDirective memory pass, bytes calldata input, uint256 offset)
        private
        pure
        returns (uint256 next)
    {
        (pass.lowTick_, pass.highTick_, pass.isTickRel_, pass.isAdd_, pass.rollType_, pass.liquidity_) =
            abi.decode(input[offset:(offset + 32 * 6)], (int24, int24, bool, bool, uint8, uint128));

        unchecked {
            // Incrementing by 196 at a time should never overflow 256 bits
            next = offset + 32 * 6;
        }
    }
}

/* @title Pool specification library.
 * @notice Library for defining, querying, and encoding the specifications of the
 *         parameters of a pool type. */
library PoolSpecs {
    /* @notice Specifcations of the parameters of a single pool type. Any given pair
     *         may have many different pool types, each of which may operate as segmented
     *         markets with different underlying behavior to the AMM. 
     *
     * @param schema_ Placeholder that defines the structure of the poolSpecs object in
     *                in storage. Because slots initialize zero, 0 is used for an 
     *                unitialized or disabled pool. 1 is the only currently used schema
     *                (for the below struct), but allows for upgradeability in the future
     *
     * @param feeRate_ The overall fee (liquidity fees + protocol fees inclusive) that
     *            swappers pay to the pool as a fraction of notional. Represented as an 
     *            integer representing hundredths of a basis point. I.e. a 0.25% fee 
     *            would be 2500
     *
     * @param protocolTake_ The fraction of the fee rate that goes to the protocol fee 
     *             (the rest accumulates as a liquidity fee to LPs). Represented in units
     *             of 1/256. Since uint8 can represent up to 255, protocol could take
     *             as much as 99.6% of liquidity fees. However currently the protocol
     *             set function prohibits values above 128, i.e. 50% of liquidity fees. 
     *             (See set ProtocolTakeRate in PoolRegistry.sol)
     *
     * @param tickSize The minimum granularity of price ticks defining a grid, on which 
     *          range orders may be placed. (Outside off-grid price improvement facility.)
     *          For example a value of 50 would mean that range order bounds could only
     *          be placed on every 50th price tick, guaranteeing a minimum separation of
     *          0.005% (50 one basis point ticks) between bump points.
     *
     * @param jitThresh_ Sets the minimum TTL for concentrated LP positions in the pool.
     *                   Represented in units of 10 seconds (as measured by block time)
     *                   E.g. a value of 5 equates to a minimum TTL of 50 seconds.
     *                   Attempts to burn or partially burn an LP position in less than
     *                   N seconds (as measured in block.timestamp) after a position was
     *                   minted (or had its liquidity increased) will revert. If set to
     *                   0, atomically flashed liquidity that mints->burns in the same
     *                   block is enabled.
     *
     * @param knockoutBits_ Defines the parameters for where and how knockout liquidity
     *                      is allowed in the pool. (See KnockoutLiq library for a full
     *                      description of the bit field.)
     *
     * @param oracleFlags_ Bitmap flags to indicate the pool's oracle permission 
     *                     requirements. Current implementation only uses the least 
     *                     significant bit, which if on checks oracle permission on every
     *                     pool related call. Otherwise pool is permissionless. */
    struct Pool {
        uint8 schema_;
        uint16 feeRate_;
        uint8 protocolTake_;
        uint16 tickSize_;
        uint8 jitThresh_;
        uint8 knockoutBits_;
        uint8 oracleFlags_;
    }

    uint8 constant BASE_SCHEMA = 1;
    uint8 constant DISABLED_SCHEMA = 0;

    /* @notice Convenience struct that's used to gather all useful context about on a 
     *         specific pool.
     * @param head_ The full specification for the pool. (See struct Pool comments above.)
     * @param hash_ The keccak256 hash used to encode the full pool location.
     * @param oracle_ The permission oracle associated with this pool (0 if pool is 
     *                permissionless.) */
    struct PoolCursor {
        Pool head_;
        bytes32 hash_;
        address oracle_;
    }

    /* @notice Given a mapping of pools, a base/quote token pair and a pool type index,
     *         copies the pool specification to memory. */
    function queryPool(mapping(bytes32 => Pool) storage pools, address tokenX, address tokenY, uint256 poolIdx)
        internal
        view
        returns (PoolCursor memory specs)
    {
        bytes32 key = encodeKey(tokenX, tokenY, poolIdx);
        Pool memory pool = pools[key];
        address oracle = oracleForPool(poolIdx, pool.oracleFlags_);
        return PoolCursor({head_: pool, hash_: key, oracle_: oracle});
    }

    /* @notice Given a mapping of pools, a base/quote token pair and a pool type index,
     *         retrieves a storage reference to the pool specification. */
    function selectPool(mapping(bytes32 => Pool) storage pools, address tokenX, address tokenY, uint256 poolIdx)
        internal
        view
        returns (Pool storage specs)
    {
        bytes32 key = encodeKey(tokenX, tokenY, poolIdx);
        return pools[key];
    }

    /* @notice Writes a pool specification for a pair and pool type combination. */
    function writePool(
        mapping(bytes32 => Pool) storage pools,
        address tokenX,
        address tokenY,
        uint256 poolIdx,
        Pool memory val
    ) internal {
        bytes32 key = encodeKey(tokenX, tokenY, poolIdx);
        pools[key] = val;
    }

    /* @notice Hashes the key associated with a pool for a base/quote asset pair and
     *         a specific pool type index. */
    function encodeKey(address tokenX, address tokenY, uint256 poolIdx) internal pure returns (bytes32) {
        require(tokenX < tokenY);
        return keccak256(abi.encode(tokenX, tokenY, poolIdx));
    }

    /* @notice Returns the permission oracle associated with the pool (or 0 if pool is
     *         permissionless. 
     *
     * @dev    The oracle (if enabled on pool settings) is always deterministically based
     *         on the first 160-bits of the pool type value. This means users can know 
     *         ahead of time if a pool can be oracled by checking the bits in the pool
     *         index. */
    function oracleForPool(uint256 poolIdx, uint8 oracleFlags) internal pure returns (address) {
        uint8 ORACLE_ENABLED_MASK = 0x1;
        bool oracleEnabled = (oracleFlags & ORACLE_ENABLED_MASK == 1);
        return oracleEnabled ? address(uint160(poolIdx >> 96)) : address(0);
    }

    /* @notice Constructs a cryptographically unique virtual address based off a base
     *         address (either virtual or real), and a salt unique to the base address.
     *         Can be used to create synthetic tokens, users, etc.
     *
     * @param base The address of the base root.
     * @param salt A salt unique to the base token tracker contract.
     *
     * @return A synthetic token address corresponding to the specific virtual address. */
    function virtualizeAddress(address base, uint256 salt) internal pure returns (address) {
        bytes32 hash = keccak256(abi.encode(base, salt));
        uint160 hashTrail = uint160((uint256(hash) << 96) >> 96);
        return address(hashTrail);
    }
}

/// @title Math library for computing sqrt prices from ticks and vice versa
/// @notice Computes sqrt price for ticks of size 1.0001, i.e. sqrt(1.0001^tick) as fixed point Q64.64 numbers. Supports
/// prices between 2**-96 and 2**120
library TickMath {
    /// @dev The minimum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**-96
    int24 internal constant MIN_TICK = -665454;
    /// @dev The maximum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**120
    int24 internal constant MAX_TICK = 831818;

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK). The reason we don't set this as min(uint128) is so that single precicion moves represent a small fraction.
    uint128 internal constant MIN_SQRT_RATIO = 65538;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint128 internal constant MAX_SQRT_RATIO = 21267430153580247136652501917186561138;

    /// @notice Calculates sqrt(1.0001^tick) * 2^64
    /// @dev Throws if tick < MIN_TICK or tick > MAX_TICK
    /// @param tick The input tick for the above formula
    /// @return sqrtPriceX64 A Fixed point Q64.64 number representing the sqrt of the ratio of the two assets (token1/token0)
    /// at the given tick
    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint128 sqrtPriceX64) {
        // Set to unchecked, but the original UniV3 library was written in a pre-checked version of Solidity
        unchecked {
            require(tick >= MIN_TICK && tick <= MAX_TICK);
            uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));

            uint256 ratio =
                absTick & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
            if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
            if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
            if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
            if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
            if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
            if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
            if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
            if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
            if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
            if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
            if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
            if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
            if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
            if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
            if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
            if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
            if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
            if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
            if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

            if (tick > 0) ratio = type(uint256).max / ratio;

            // this divides by 1<<64 rounding up to go from a Q128.128 to a Q64.64
            // we then downcast because we know the result always fits within 128 bits due to our tick input constraint
            // we round up in the division so getTickAtSqrtRatio of the output price is always consistent
            sqrtPriceX64 = uint128((ratio >> 64) + (ratio % (1 << 64) == 0 ? 0 : 1));
        }
    }

    /// @notice Calculates the greatest tick value such that getRatioAtTick(tick) <= ratio
    /// @dev Throws in case sqrtPriceX64 < MIN_SQRT_RATIO, as MIN_SQRT_RATIO is the lowest value getRatioAtTick may
    /// ever return.
    /// @param sqrtPriceX64 The sqrt ratio for which to compute the tick as a Q64.64
    /// @return tick The greatest tick for which the ratio is less than or equal to the input ratio
    function getTickAtSqrtRatio(uint128 sqrtPriceX64) internal pure returns (int24 tick) {
        // Set to unchecked, but the original UniV3 library was written in a pre-checked version of Solidity
        unchecked {
            // second inequality must be < because the price can never reach the price at the max tick
            require(sqrtPriceX64 >= MIN_SQRT_RATIO && sqrtPriceX64 < MAX_SQRT_RATIO);
            uint256 ratio = uint256(sqrtPriceX64) << 64;

            uint256 r = ratio;
            uint256 msb = 0;

            assembly {
                let f := shl(7, gt(r, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
                msb := or(msb, f)
                r := shr(f, r)
            }
            assembly {
                let f := shl(6, gt(r, 0xFFFFFFFFFFFFFFFF))
                msb := or(msb, f)
                r := shr(f, r)
            }
            assembly {
                let f := shl(5, gt(r, 0xFFFFFFFF))
                msb := or(msb, f)
                r := shr(f, r)
            }
            assembly {
                let f := shl(4, gt(r, 0xFFFF))
                msb := or(msb, f)
                r := shr(f, r)
            }
            assembly {
                let f := shl(3, gt(r, 0xFF))
                msb := or(msb, f)
                r := shr(f, r)
            }
            assembly {
                let f := shl(2, gt(r, 0xF))
                msb := or(msb, f)
                r := shr(f, r)
            }
            assembly {
                let f := shl(1, gt(r, 0x3))
                msb := or(msb, f)
                r := shr(f, r)
            }
            assembly {
                let f := gt(r, 0x1)
                msb := or(msb, f)
            }

            if (msb >= 128) r = ratio >> (msb - 127);
            else r = ratio << (127 - msb);

            int256 log_2 = (int256(msb) - 128) << 64;

            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(63, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(62, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(61, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(60, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(59, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(58, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(57, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(56, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(55, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(54, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(53, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(52, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(51, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(50, f))
            }

            int256 log_sqrt10001 = log_2 * 255738958999603826347141; // 128.128 number

            int24 tickLow = int24((log_sqrt10001 - 3402992956809132418596140100660247210) >> 128);
            int24 tickHi = int24((log_sqrt10001 + 291339464771989622907027621153398088495) >> 128);

            tick = tickLow == tickHi ? tickLow : getSqrtRatioAtTick(tickHi) <= sqrtPriceX64 ? tickHi : tickLow;
        }
    }
}

/// @title FixedPoint128
/// @notice A library for handling binary fixed point numbers, see https://en.wikipedia.org/wiki/Q_(number_format)
library FixedPoint {
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
    uint256 internal constant Q64 = 0x10000000000000000;
    uint256 internal constant Q48 = 0x1000000000000;

    /* @notice Multiplies two Q64.64 numbers by each other. */
    function mulQ64(uint128 x, uint128 y) internal pure returns (uint192) {
        unchecked {
            // 128 bit integers squared will always fit in 256-bits
            return uint192((uint256(x) * uint256(y)) >> 64);
        }
    }

    /* @notice Divides one Q64.64 number by another. */
    function divQ64(uint128 x, uint128 y) internal pure returns (uint192) {
        unchecked {
            // No overflow or underflow possible in the below operations
            return (uint192(x) << 64) / y;
        }
    }

    /* @notice Multiplies a Q64.64 by a Q16.48. */
    function mulQ48(uint128 x, uint64 y) internal pure returns (uint144) {
        unchecked {
            // 128 bit integers squared will always fit in 256-bits
            return uint144((uint256(x) * uint256(y)) >> 48);
        }
    }

    /* @notice Takes the reciprocal of a Q64.64 number. */
    function recipQ64(uint128 x) internal pure returns (uint128) {
        unchecked {
            // Only possible overflow possible is captured with a specific check
            uint256 div = uint256(FixedPoint.Q128) / uint256(x);
            require(div <= type(uint128).max);
            return uint128(div);
        }
    }
}

/// @title Math library for liquidity
library LiquidityMath {
    /// @notice Add a signed liquidity delta to liquidity and revert if it overflows or underflows
    /// @param x The liquidity before change
    /// @param y The delta by which liquidity should be changed
    /// @return z The liquidity delta
    function addDelta(uint128 x, int128 y) internal pure returns (uint128 z) {
        unchecked {
            // Arithmetic checks done explicitly
            if (y < 0) {
                require((z = x - uint128(-y)) < x);
            } else {
                require((z = x + uint128(y)) >= x);
            }
        }
    }

    /// @notice Add an unsigned liquidity delta to liquidity and revert if it overflows or underflows
    /// @param x The liquidity before change
    /// @param y The delta by which liquidity should be changed
    /// @return z The liquidity delta
    function addLiq(uint128 x, uint128 y) internal pure returns (uint128 z) {
        unchecked {
            // Arithmetic checks done explicitly
            require((z = x + y) >= x);
        }
    }

    /// @notice Add an unsigned liquidity delta to liquidity and revert if it overflows or underflows
    /// @param x The liquidity before change
    /// @param y The delta by which liquidity should be changed
    /// @return z The liquidity delta
    function addLots(uint96 x, uint96 y) internal pure returns (uint96 z) {
        unchecked {
            // Arithmetic checks done explicitly
            require((z = x + y) >= x);
        }
    }

    /// @notice Subtract an unsigned liquidity delta to liquidity and revert if it overflows or underflows
    /// @param x The liquidity before change
    /// @param y The delta by which liquidity should be changed
    /// @return z The liquidity delta
    function minusDelta(uint128 x, uint128 y) internal pure returns (uint128 z) {
        z = x - y;
    }

    /* @notice Same as minusDelta, but operates on lots of liquidity rather than outright
     *         liquiidty. */
    function minusLots(uint96 x, uint96 y) internal pure returns (uint96 z) {
        z = x - y;
    }

    /* In certain contexts we need to represent liquidity, but don't have the full 128 
     * bits or precision. The compromise is to use "lots" of liquidity, which is liquidity
     * represented as multiples of 1024. Usually in those contexts, max lots is capped at
     * 2^96 (equivalent to 2^106 of liquidity.) 
     *
     * More explanation, along with examples can be found in the documentation at 
     * docs/LiquidityLots.md in the project respository. */
    uint16 constant LOT_SIZE = 1024;
    uint8 constant LOT_SIZE_BITS = 10;

    /* By utilizing the least significant digit of the liquidity lots value, we can 
     * support special types of "knockout" liquidity, that when crossed trigger specific
     * calls. The aggregate knockout liquidity will always sum to an odd number of lots
     * whereas all vanilla resting liquidity will have an even number of lots. That
     * means we can test whether any level has knockout liquidity simply by seeing if the
     * the total sum is an odd number. 
     *
     * More explanation, along with examples can be found in the documentation at 
     * docs/LiquidityLots.md in the project respository. */
    uint96 constant KNOCKOUT_FLAG_MASK = 0x1;
    uint8 constant LOT_ACTIVE_BITS = 11;

    /* @notice Converts raw liquidity to lots of resting liquidity. (See comment above 
     *         defining lots. */
    function liquidityToLots(uint128 liq) internal pure returns (uint96) {
        uint256 lots = liq >> LOT_SIZE_BITS;
        uint256 liqTrunc = lots << LOT_SIZE_BITS;
        bool hasEmptyMask = (lots & KNOCKOUT_FLAG_MASK == 0);
        require(hasEmptyMask && liqTrunc == liq && lots < type(uint96).max, "FD");
        return uint96(lots);
    }

    /* @notice Checks if an aggergate lots counter contains a knockout liquidity component
     *         by checking the least significant bit.
     *
     * @dev    Note that it's critical that the sum *total* of knockout lots on any
     *         given level be an odd number. Don't add two odd knockout lots together
     *         without renormalzing, because they'll sum to an even lot quantity. */
    function hasKnockoutLiq(uint96 lots) internal pure returns (bool) {
        return lots & KNOCKOUT_FLAG_MASK > 0;
    }

    /* @notice Truncates an existing liquidity quantity into a quantity that's a multiple
     *         of the 2048-multiplier defining even-sized lots of liquidity. */
    function shaveRoundLots(uint128 liq) internal pure returns (uint128) {
        return (liq >> LOT_ACTIVE_BITS) << LOT_ACTIVE_BITS;
    }

    /* @notice Truncates an existing liquidity quantity into a quantity that's a multiple
     *         of the 2048-multiplier defining even-sized lots of liquidity, but rounds up 
     *         to the next multiple of 2048. */
    function shaveRoundLotsUp(uint128 liq) internal pure returns (uint128 result) {
        unchecked {
            require((liq & 0xfffffffffffffffffffffffffffff800) != 0xfffffffffffffffffffffffffffff800, "overflow");

            // By shifting down 11 bits, adding the one will always fit in 128 bits
            uint128 roundUp = (liq >> LOT_ACTIVE_BITS) + 1;
            return (roundUp << LOT_ACTIVE_BITS);
        }
    }

    /* @notice Given a number of lots of liquidity converts to raw liquidity value. */
    function lotsToLiquidity(uint96 lots) internal pure returns (uint128) {
        uint96 realLots = lots & ~KNOCKOUT_FLAG_MASK;
        return uint128(realLots) << LOT_SIZE_BITS;
    }

    /* @notice Given a positive and negative delta lots value net out the raw liquidity
     *         delta. */
    function netLotsOnLiquidity(uint96 incrLots, uint96 decrLots) internal pure returns (int128) {
        unchecked {
            // Original values are 96-bits, every possible difference will fit in signed-128 bits
            return lotToNetLiq(incrLots) - lotToNetLiq(decrLots);
        }
    }

    /* @notice Given an amount of lots of liquidity converts to a signed raw liquidity
     *         delta. (Which by definition is always positive.) */
    function lotToNetLiq(uint96 lots) internal pure returns (int128) {
        return int128(lotsToLiquidity(lots));
    }

    /* @notice Blends the weighted average of two fee reward accumulators based on the
     *         relative size of two liquidity position.
     *
     * @dev To be conservative in terms of rewards/collateral, this function always
     *   rounds up to 2 units of precision. We need mileage rounded up, so reward payouts
     *   are rounded down. However this could lead to the technically "impossible" 
     *   situation where the mileage on a subsequent rewards burn is smaller than the
     *   blended mileage in the liquidity postion. Technically this shouldn't happen 
     *   because mileage only increases through time. However this is a non-consequential
     *   failure. burnPosLiq() just treats it as a zero reward situation, and the staker
     *   loses an economically non-meaningful amount of rewards on the burn. */
    function blendMileage(uint64 mileageX, uint128 liqX, uint64 mileageY, uint128 liqY)
        internal
        pure
        returns (uint64)
    {
        if (liqY == 0) return mileageX;
        if (liqX == 0) return mileageY;
        if (mileageX == mileageY) return mileageX;
        uint64 termX = calcBlend(mileageX, liqX, liqX + liqY);
        uint64 termY = calcBlend(mileageY, liqY, liqX + liqY);

        // With mileage we want to be conservative on the upside. Under-estimating
        // mileage means overpaying rewards. So, round up the fractional weights.
        return (termX + 1) + (termY + 1);
    }

    /* @notice Calculates a weighted blend of adding incremental rewards mileage. */
    function calcBlend(uint64 mileage, uint128 weight, uint128 total) private pure returns (uint64) {
        unchecked {
            // Intermediate results will always fit in 256-bits
            // Can safely cast, because result will always be smaller than original since
            // weight is less than total.
            return uint64(uint256(mileage) * uint256(weight) / uint256(total));
        }
    }

    /* @dev Computes a rounding safe calculation of the accumulated rewards rate based on
     *      a beginning and end mileage counter. */
    function deltaRewardsRate(uint64 feeMileage, uint64 oldMileage) internal pure returns (uint64) {
        uint64 REWARD_ROUND_DOWN = 2;
        if (feeMileage > oldMileage + REWARD_ROUND_DOWN) {
            return feeMileage - oldMileage - REWARD_ROUND_DOWN;
        } else {
            return 0;
        }
    }
}

/* @title Compounding math library
 * @notice Library provides convenient math functionality for various transformations
 *         and reverse transformations related to compound growth. */
library CompoundMath {
    using SafeCast for uint256;

    /* @notice Provides a safe lower-bound approximation of the square root of (1+x)
     *         based on a two-term Taylor series expansion. The purpose is to calculate
     *         the square root for small compound growth rates. 
     * 
     *         Both the input and output values are passed as the growth rate *excluding*
     *         the 1.0 multiplier base. For example assume the input (X) is 0.1, then the
     *         output Y is:
     *             (1 + Y) = sqrt(1+X)
     *             (1 + Y) = sqrt(1 + 0.1)
     *             (1 + Y) = 1.0488 (approximately)
     *                   Y = 0.0488 (approximately)
     *         In the example the square root of 10% compound growth is 4.88%
     *
     *         Another example, assume the input (X) is 0.6, then the output (Y) is:
     *             (1 + Y) = sqrt(1+X)
     *             (1 + Y) = sqrt(1 + 0.6)
     *             (1 + Y) = 1.264 (approximately)
     *                   Y = 0.264 (approximately)
     *         In the example the square root of 60% growth is 26.4% compound growth
     *
     *         Another example, assume the input (X) is 0.018, then the output (Y) is:
     *             (1 + Y) = sqrt(1+X)
     *             (1 + Y) = sqrt(1 + 0.018)
     *             (1 + Y) = 1.00896 (approximately)
     *                   Y = 0.00896 (approximately)
     *         In the example the square root of 1.8% growth is 0.896% compound growth
     *
     * @dev    Due to approximation error, only safe to use on input in the range of 
     *         [0,1). Will always round down from the true real value.
     *
     * @param x  The value of x in (1+x). Represented as a Q16.48 fixed-point
     * @returns   The value of y for which (1+y) = sqrt(1+x). Represented as Q16.48 fixed point
     * */
    function approxSqrtCompound(uint64 x64) internal pure returns (uint64) {
        // Taylor series error becomes too large above 2.0. Approx is still conservative
        // but the angel's share becomes unreasonable.
        require(x64 < FixedPoint.Q48);

        unchecked {
            uint256 x = uint256(x64);
            // Shift by 48, to bring x^2 back in fixed point precision
            uint256 xSq = (x * x) >> 48; // x * x never overflows 256 bits, because x is 64 bits
            uint256 linear = x >> 1; // Linear Taylor series term is x/2
            uint256 quad = xSq >> 3; // Quadratic Tayler series term ix x^2/8;

            // This will always fit in 64 bits because result is smaller than original/
            // Will always be greater than 0, because x^2 < x for x < 1
            return uint64(linear - quad);
        }
    }

    /* @notice Computes the result from compounding two cumulative growth rates.
     * @dev    Rounds down from the real value. Caps the result if type exceeds the max
     *         fixed-point value.
     * @param x The compounded growth rate as in (1+x). Represted as Q16.48 fixed-point.
     * @param y The compounded growth rate as in (1+y). Represted as Q16.48 fixed-point.
     * @returns The cumulative compounded growth rate as in (1+z) = (1+x)*(1+y).
     *          Represented as Q16.48 fixed-point. */
    function compoundStack(uint64 x, uint64 y) internal pure returns (uint64) {
        unchecked {
            uint256 ONE = FixedPoint.Q48;
            uint256 num = (ONE + x) * (ONE + y); // Never overflows 256-bits because x and y are 64 bits
            uint256 term = num >> 48; // Divide by 48-bit ONE
            uint256 z = term - ONE; // term will always be >= ONE
            if (z >= type(uint64).max) return type(uint64).max;
            return uint64(z);
        }
    }

    /* @notice Computes the result from backing out a compounded growth value from
     *         an existing value. The inverse of compoundStack().
     * @dev    Rounds down from the real value.
     * @param val The fixed price representing the starting value that we want
     *            to back out a pre-growth seed from.
     * @param deflator The compounded growth rate to back out, as in (1+g). Represented
     *                 as Q16.48 fixed-point
     * @returns The pre-growth value as in val/(1+g). Rounded down as an unsigned
     *          integer. */
    function compoundShrink(uint64 val, uint64 deflator) internal pure returns (uint64) {
        unchecked {
            uint256 ONE = FixedPoint.Q48;
            uint256 multFactor = ONE + deflator; // Never overflows because both fit inside 64 bits
            uint256 num = uint256(val) << 48; // multiply by 48-bit ONE
            uint256 z = num / multFactor; // multFactor will never be zero because it's bounded by 1
            return uint64(z); // Will always fit in 64-bits because shrink can only decrease
        }
    }

    /* @notice Computes the implied compound growth rate based on the division of two
     *     arbitrary quantities.
     * @dev    Based on this function's use, calulated growth rate will always be 
     *         capped at 100%. The implied growth rate must always be non-negative.
     * @param inflated The larger value to be divided. Any 128-bit integer or fixed point
     * @param seed The smaller value to use as a divisor. Any 128-bit integer or fixed 
     *             point.
     * @returns The cumulative compounded growth rate as in (1+z) = (1+x)/(1+y).
     *          Represeted as Q16.48. */
    function compoundDivide(uint128 inflated, uint128 seed) internal pure returns (uint64) {
        // Otherwise arithmetic doesn't safely fit in 256 -bit
        require(inflated < type(uint208).max && inflated >= seed);

        unchecked {
            uint256 ONE = FixedPoint.Q48;
            uint256 num = uint256(inflated) << 48;
            uint256 z = (num / seed) - ONE; // Never underflows because num is always greater than seed

            if (z >= ONE) return uint64(ONE);
            return uint64(z);
        }
    }

    /* @notice Calculates a final price from applying a growth rate to a starting price.
     * @dev    Always rounds in the direction of @shiftUp
     * @param price The starting price to be compounded. Q64.64 fixed point.
     * @param growth The compounded growth rate to apply, as in (1+g). Represented
     *                as Q16.48 fixed-point
     * @param shiftUp If true compounds the starting price up, so the result will be 
     *                greater. If false, compounds the price down so the result will be
     *                smaller than the original price.
     * @returns The post-growth price as in price*(1+g) (or price*(1-g) if shiftUp is 
     *          false). Q64.64 always rounded in the direction of shiftUp. */
    function compoundPrice(uint128 price, uint64 growth, bool shiftUp) internal pure returns (uint128) {
        unchecked {
            uint256 ONE = FixedPoint.Q48;
            uint256 multFactor = ONE + growth; // Guaranteed to fit in 65-bits

            if (shiftUp) {
                uint256 num = uint256(price) * multFactor; // Guaranteed to fit in 193 bits
                uint256 z = num >> 48; // De-scale by the 48-bit growth precision
                return (z + 1).toUint128(); // Round in the price shift
            } else {
                uint256 num = uint256(price) << 48;
                // No need to safe cast, since this will be smaller than original price
                return uint128(num / multFactor);
            }
        }
    }

    /* @notice Inflates a starting value by a cumulative growth rate.
     * @dev    Rounds down from the real value. Result is capped at max(uint128).
     * @param seed The pre-inflated starting value as unsigned integer
     * @param growth Cumulative growth rate as Q16.48 fixed-point
     * @return The ending value = seed * (1 + growth). Rounded down to nearest
     *         integer value */
    function inflateLiqSeed(uint128 seed, uint64 growth) internal pure returns (uint128) {
        unchecked {
            uint256 ONE = FixedPoint.Q48;
            uint256 num = uint256(seed) * uint256(ONE + growth); // Guaranteed to fit in 256
            uint256 inflated = num >> 48; // De-scale by the 48-bit growth precision;

            if (inflated > type(uint128).max) return type(uint128).max;
            return uint128(inflated);
        }
    }

    /* @notice Deflates a starting value by a cumulative growth rate.
     * @dev    Rounds down from the real value.
     * @param liq The post-inflated liquidity as unsigned integer
     * @param growth Cumulative growth rate as Q16.48 fixed-point
     * @return The ending value = liq / (1 + growth). Rounded down to nearest
     *         integer value */
    function deflateLiqSeed(uint128 liq, uint64 growth) internal pure returns (uint128) {
        unchecked {
            uint256 ONE = FixedPoint.Q48;
            uint256 num = uint256(liq) << 48;
            uint256 deflated = num / (ONE + growth); // Guaranteed to fit in 256-bits

            // No need to safe cast-- will allways be smaller than starting
            return uint128(deflated);
        }
    }
}

/* @title Curve and swap math library
 * @notice Library that defines locally stable constant liquidity curves and
 *         swap struct, as well as functions to derive impact and aggregate 
 *         liquidity measures on these objects. */
library CurveMath {
    using LiquidityMath for uint128;
    using CompoundMath for uint256;
    using SafeCast for uint256;
    using SafeCast for uint192;

    /* All CrocSwap swaps occur as legs across locally stable constant-product AMM
     * curves. For large moves across tick boundaries, the state of this curve might 
     * change as range-bound liquidity is kicked in or out of the currently active 
     * curve. But for small moves within tick boundaries (or between tick boundaries 
     * with no liquidity bumps), the curve behaves like a classic constant-product AMM.
     *
     * CrocSwap tracks two types of liquidity. 1) Ambient liquidity that is non-
     * range bound and remains active at all prices from zero to infinity, until 
     * removed by the staking user. 2) Concentrated liquidity that is tied to an 
     * arbitrary lower<->upper tick range and is kicked out of the curve when the
     * price moves out of range.
     *
     * In the CrocSwap model all collected fees are directly incorporated as expanded
     * liquidity onto the curve itself. (See CurveAssimilate.sol for more on the 
     * mechanics.) All accumulated fees are added as ambient-type liquidity, even those
     * fees that belong to the pro-rata share of the active concentrated liquidity.
     * This is because on an aggregate level, we can't break down the pro-rata share
     * of concentrated rewards to the potentially near infinite concentrated range
     * possibilities.
     *
     * Because of this concentrated liquidity can be flatly represented as 1:1 with
     * contributed liquidity. Ambient liquidity, in contrast, deflates over time as
     * it accumulates rewards. Therefore it's represented in terms of seed amount,
     * i.e. the equivalent of 1 unit of ambient liquidity contributed at the inception
     * of the pool. As fees accumulate the conversion rate from seed to liquidity 
     * continues to increase. 
     *
     * Finally concentrated liquidity rewards are represented in terms of accumulated
     * ambient seeds. This automatically takes care of the compounding of ambient 
     * rewards compounded on top of concentrated rewards. 
     *
     * @param priceRoot_ The square root of the price ratio exchange rate between the
     *   base and quote-side tokens in the AMM curve. (represented in Q64.64 fixed point)
     * @param ambientSeeds_ The total ambient liquidity seeds in the current curve. 
     *   (Inflated by seed deflator to get efective ambient liquidity)
     * @param concLiq_ The total concentrated liquidity active and in range at the
     *   current state of the curve.
     * @param seedDeflator_ The cumulative growth rate (represented as Q16.48 fixed
     *    point) of a hypothetical 1-unit of ambient liquidity held in the pool since
     *    inception.
     * @param concGrowth_ The cumulative rewards growth rate (represented as Q16.48
     *   fixed point) of hypothetical 1 unit of concentrated liquidity in range in the
     *   pool since inception. 
     *
     * @dev Price ratio is stored as a square root because it makes reserve calculation
     *      arithmetic much easier. To be conservative with collateral these growth 
     *      rates should always be rounded down from their real-value results. Some 
     *      minor lower-bound approximation is fine, since all it will result in is 
     *      slightly smaller reward payouts. */
    struct CurveState {
        uint128 priceRoot_;
        uint128 ambientSeeds_;
        uint128 concLiq_;
        uint64 seedDeflator_;
        uint64 concGrowth_;
    }

    /* @notice Calculates the total amount of liquidity represented by the liquidity 
     *         curve object.
     * @dev    Result always rounds down from the real value, *assuming* that the fee
     *         accumulation fields are conservative lower-bound rounded.
     * @param curve - The currently active liqudity curve state. Remember this curve 
     *    state is only known to be valid within the current tick.
     * @return - The total scalar liquidity. Equivalent to sqrt(X*Y) in an equivalent 
     *           constant-product AMM. */
    function activeLiquidity(CurveState memory curve) internal pure returns (uint128) {
        uint128 ambient = CompoundMath.inflateLiqSeed(curve.ambientSeeds_, curve.seedDeflator_);
        return LiquidityMath.addLiq(ambient, curve.concLiq_);
    }

    /* @notice Similar to calcLimitFlows(), except returns the max possible flow in the
     *   *opposite* direction. I.e. if inBaseQty_ is True, returns the quote token flow
     *   for the swap. And vice versa..
     *
     * @dev The fixed-point result approximates the real valued formula with close but
     *   directionally unpredicable precision. It could be slightly above or slightly
     *   below. In the case of zero flows this could be substantially over. This 
     *   function should not be used in any context with strict directional boundness 
     *   requirements. */
    function calcLimitCounter(CurveState memory curve, uint128 swapQty, bool inBaseQty, uint128 limitPrice)
        internal
        pure
        returns (uint128)
    {
        bool isBuy = limitPrice > curve.priceRoot_;
        uint128 denomFlow = calcLimitFlows(curve, swapQty, inBaseQty, limitPrice);
        return invertFlow(activeLiquidity(curve), curve.priceRoot_, denomFlow, isBuy, inBaseQty);
    }

    /* @notice Calculates the total quantity of tokens that can be swapped on the AMM
     *   curve until either 1) the limit price is reached or 2) the swap fills its 
     *   entire remaining quantity.
     *
     * @dev This function does *NOT* account for the possibility of concentrated liq
     *   being knocked in/out as the price on the AMM curve moves across tick boundaries.
     *   It's the responsibility of the caller to properly check whether the limit price
     *   is within the bounds of the locally stable curve.
     *
     * @dev As long as CurveState's fee accum fields are conservatively lower bounded,
     *   and as long as limitPrice is accurate, then this function rounds down from the
     *   true real value. At most this round down loss of precision is tightly bounded at
     *   2 wei. (See comments in deltaPriceQuote() function)
     * 
     * @param curve - The current state of the liquidity curve. No guarantee that it's
     *   liquidity stable through the entire limit range (see @dev above). Note that this
     *   function does *not* update the curve struct object.   
     * @param swapQty - The total remaining quantity left in the swap.
     * @param inBaseQty - Whether the swap quantity is denomianted in base or quote side
     *                    token.
     * @param limitPrice - The highest (lowest) acceptable ending price of the AMM curve
     *   for a buy (sell) swap. Represented as Q64.64 fixed point square root of the 
     *   price. 
     *
     * @return - The maximum executable swap flow (rounded down by fixed precision).
     *           Denominated on the token side based on inBaseQty param. Will
     *           always return unsigned magnitude regardless of the direction. User
     *           can easily determine based on swap context. */
    function calcLimitFlows(CurveState memory curve, uint128 swapQty, bool inBaseQty, uint128 limitPrice)
        internal
        pure
        returns (uint128)
    {
        uint128 limitFlow = calcLimitFlows(curve, inBaseQty, limitPrice);
        return limitFlow > swapQty ? swapQty : limitFlow;
    }

    function calcLimitFlows(CurveState memory curve, bool inBaseQty, uint128 limitPrice)
        private
        pure
        returns (uint128)
    {
        uint128 liq = activeLiquidity(curve);
        return inBaseQty ? deltaBase(liq, curve.priceRoot_, limitPrice) : deltaQuote(liq, curve.priceRoot_, limitPrice);
    }

    /* @notice Calculates the change to base token reserves associated with a price
     *   move along an AMM curve of constant liquidity.
     *
     * @dev Result is a tight lower-bound for fixed-point precision. Meaning if the
     *   the returned limit is X, then X will be inside the limit price and (X+1)
     *   will be outside the limit price. */
    function deltaBase(uint128 liq, uint128 priceX, uint128 priceY) internal pure returns (uint128) {
        unchecked {
            uint128 priceDelta = priceX > priceY ? priceX - priceY : priceY - priceX; // Condition assures never underflows
            return reserveAtPrice(liq, priceDelta, true);
        }
    }

    /* @notice Calculates the change to quote token reserves associated with a price
     *   move along an AMM curve of constant liquidity.
     * 
     * @dev Result is almost always within a fixed-point precision unit from the true
     *   real value. However in certain rare cases, the result could be up to 2 wei
     *   below the true mathematical value. Caller should account for this */
    function deltaQuote(uint128 liq, uint128 price, uint128 limitPrice) internal pure returns (uint128) {
        // For purposes of downstream calculations, we make sure that limit price is
        // larger. End result is symmetrical anyway
        if (limitPrice > price) {
            return calcQuoteDelta(liq, limitPrice, price);
        } else {
            return calcQuoteDelta(liq, price, limitPrice);
        }
    }

    /* The formula calculated is
     *    F = L * d / (P*P')
     *   (where F is the flow to the limit price, where L is liquidity, d is delta, 
     *    P is price and P' is limit price)
     *
     * Calculating this requires two stacked mulDiv. To meet the function's contract
     * we need to compute the result with tight fixed point boundaries at or below
     * 2 wei to conform to the function's contract.
     * 
     * The fixed point calculation of flow is
     *    F = mulDiv(mulDiv(...)) = FR - FF
     *  (where F is the fixed point result of the formula, FR is the true real valued
     *   result with inifnite precision, FF is the loss of precision fractional round
     *   down, mulDiv(...) is a fixed point mulDiv call of the form X*Y/Z)
     *
     * The individual fixed point terms are
     *    T1 = mulDiv(X1, Y1, Z1) = T1R - T1F
     *    T2 = mulDiv(T1, Y2, Z2) = T2R - T2F
     *  (where T1 and T2 are the fixed point results from the first and second term,
     *   T1R and T2R are the real valued results from an infinite precision mulDiv,
     *   T1F and T2F are the fractional round downs, X1/Y1/Z1/Y2/Z2 are the arbitrary
     *   input terms in the fixed point calculation)
     *
     * Therefore the total loss of precision is
     *    FF = T2F + T1F * T2R/T1
     *
     * To guarantee a 2 wei precision loss boundary:
     *    FF <= 2
     *    T2F + T1F * T2R/T1 <= 2
     *    T1F * T2R/T1 <=  1      (since T2F as a round-down is always < 1)
     *    T2R/T1 <= 1             (since T1F as a round-down is always < 1)
     *    Y2/Z2 >= 1
     *    Z2 >= Y2 */
    function calcQuoteDelta(uint128 liq, uint128 priceBig, uint128 priceSmall) private pure returns (uint128) {
        uint128 priceDelta = priceBig - priceSmall;

        // This is cast to uint256 but is guaranteed to be less than 2^192 based off
        // the return type of divQ64
        uint256 termOne = FixedPoint.divQ64(liq, priceSmall);

        // As long as the final result doesn't overflow from 128-bits, this term is
        // guaranteed not to overflow from 256 bits. That's because the final divisor
        // can be at most 128-bits, therefore this intermediate term must be 256 bits
        // or less.
        //
        // By definition priceBig is always larger than priceDelta. Therefore the above
        // condition of Z2 >= Y2 is satisfied and the equation caps at a maximum of 2
        // wei of precision loss.
        uint256 termTwo = termOne * uint256(priceDelta) / uint256(priceBig);
        return termTwo.toUint128();
    }

    /* @notice Returns the amount of virtual reserves give the price and liquidity of the
     *   constant-product liquidity curve.
     *
     * @dev The actual pool probably holds significantly less collateral because of the 
     *   use of concentrated liquidity. 
     * @dev Results always round down from the precise real-valued mathematical result.
     * 
     * @param liq - The total active liquidity in AMM curve. Represented as sqrt(X*Y)
     * @param price - The current active (square root of) price of the AMM curve. 
     *                 represnted as Q64.64 fixed point
     * @param inBaseQty - The side of the pool to calculate the virtual reserves for.
     *
     * @returns The virtual reserves of the token (rounded down to nearest integer). 
     *   Equivalent to the amount of tokens that would be held for an equivalent 
     *   classical constant- product AMM without concentrated liquidity.  */
    function reserveAtPrice(uint128 liq, uint128 price, bool inBaseQty) internal pure returns (uint128) {
        return (inBaseQty ? uint256(FixedPoint.mulQ64(liq, price)) : uint256(FixedPoint.divQ64(liq, price))).toUint128();
    }

    /* @notice Calculated the amount of concentrated liquidity within a price range
     *         supported by a fixed amount of collateral. Note that this calculates the 
     *         collateral only needed by one side of the pair.
     *
     * @dev    Always rounds fixed-point arithmetic result down. 
     *
     * @param collateral The total amount of token collateral being pledged.
     * @param inBase If true, the collateral represents the base-side token in the pair.
     *               If false the quote side token.
     * @param priceX The price boundary of the concentrated liquidity position.
     * @param priceY The other price boundary of the concentrated liquidity position.
     * @returns The total amount of liquidity supported by the collateral. */
    function liquiditySupported(uint128 collateral, bool inBase, uint128 priceX, uint128 priceY)
        internal
        pure
        returns (uint128)
    {
        if (!inBase) {
            return liquiditySupported(collateral, true, FixedPoint.recipQ64(priceX), FixedPoint.recipQ64(priceY));
        } else {
            unchecked {
                uint128 priceDelta = priceX > priceY ? priceX - priceY : priceY - priceX; // Conditional assures never underflows
                return liquiditySupported(collateral, true, priceDelta);
            }
        }
    }

    /* @notice Calculated the amount of ambient liquidity supported by a fixed amount of 
     *         collateral. Note that this calculates the collateral only needed by one
     *         side of the pair.
     *
     * @dev    Always rounds fixed-point arithmetic result down. 
     *
     * @param collateral The total amount of token collateral being pledged.
     * @param inBase If true, the collateral represents the base-side token in the pair.
     *               If false the quote side token.
     * @param price The current (square root) price of the curve as Q64.64 fixed point.
     * @returns The total amount of ambient liquidity supported by the collateral. */
    function liquiditySupported(uint128 collateral, bool inBase, uint128 price) internal pure returns (uint128) {
        return inBase
            ? FixedPoint.divQ64(collateral, price).toUint128By192()
            : FixedPoint.mulQ64(collateral, price).toUint128By192();
    }

    /* @dev The fixed point arithmetic results in output that's a close approximation
     *   to the true real value, but could be skewed in either direction. The output
     *   from this function should not be consumed in any context that requires strict
     *   boundness. */
    function invertFlow(uint128 liq, uint128 price, uint128 denomFlow, bool isBuy, bool inBaseQty)
        private
        pure
        returns (uint128)
    {
        if (liq == 0) return 0;

        uint256 invertReserve = reserveAtPrice(liq, price, !inBaseQty);
        uint256 initReserve = reserveAtPrice(liq, price, inBaseQty);

        unchecked {
            uint256 endReserve = (isBuy == inBaseQty)
                ? initReserve + denomFlow // Will always fit in 256-bits
                : initReserve - denomFlow; // flow is always less than total reserves
            if (endReserve == 0) return type(uint128).max;

            uint256 endInvert = uint256(liq) * uint256(liq) / endReserve;
            return (endInvert > invertReserve ? endInvert - invertReserve : invertReserve - endInvert).toUint128();
        }
    }

    /* @notice Computes the amount of token over-collateralization needed to buffer any 
     *   loss of precision rounding in the fixed price arithmetic on curve price. This
     *   is necessary because price occurs in different units than tokens, and we can't
     *   assume a single wei is sufficient to buffer one price unit.
     * 
     * @dev In practice the price unit precision is almost always smaller than the token
     *   token precision. Therefore the result is usually just 1 wei. The exception are
     *   pools where liquidity is very high or price is very low. 
     *
     * @param liq The total liquidity in the curve.
     * @param price The (square root) price of the curve in Q64.64 fixed point
     * @param inBase If true calculate the token precision on the base side of the pair.
     *               Otherwise, calculate on the quote token side. 
     *
     * @return The conservative upper bound in number of tokens that should be 
     *   burned to over-collateralize a single precision unit of price rounding. If
     *   the price arithmetic involves multiple units of precision loss, this number
     *   should be multiplied by that factor. */
    function priceToTokenPrecision(uint128 liq, uint128 price, bool inBase) internal pure returns (uint128) {
        unchecked {
            // To provide more base token collateral than price precision rounding:
            //     delta(B) >= L * delta(P)
            //     delta(P) <= 2^-64  (64 bit precision rounding)
            //     delta(B) >= L * 2^-64
            //  (where L is liquidity, B is base token reserves, P is price)
            if (inBase) {
                // Since liq is shifted right by 64 bits, adding one can never overflow
                return (liq >> 64) + 1;
            } else {
                // Calculate the quote reservs at the current price and a one unit price step,
                // then take the difference as the minimum required quote tokens needed to
                // buffer that price step.
                uint192 step = FixedPoint.divQ64(liq, price - 1);
                uint192 start = FixedPoint.divQ64(liq, price);

                // next reserves will always be equal or greater than start reserves, so the
                // subtraction will never underflow.
                uint192 delta = step - start;

                // Round tokens up conservative.
                // This will never overflow because 192 bit nums incremented by 1 will always fit in
                // 256 bits.
                uint256 deltaRound = uint256(delta) + 1;

                return deltaRound.toUint128();
            }
        }
    }
}

/* @title Price grid library.
 * @notice Functionality for tick-defined price grids and facilities for off-grid
 *         price improvement. */
library PriceGrid {
    using TickMath for int24;
    using SafeCast for uint256;
    using SafeCast for uint192;

    /* @notice Defines the off-grid price improvement options (if any) available to
     *         the user for new range orders on a specific pair.
     *
     * @param inBase_ If true the collateral thresholds apply to the base-side tokens.
     *                If false, applies to the quote-side tokens.
     * @param unitCollateral_ The minimum collateral commitment required for an off-grid
     *                range order *per tick* that's off grid.
     * @param awayTicks_ The maximum number of ticks away from the current price that an
     *                off-grid range order is allowed. */
    struct ImproveSettings {
        bool inBase_;
        uint128 unitCollateral_;
        uint16 awayTicks_;
    }

    /* @notice Asserts that a given range order is either on grid or eligble for off-grid
     *         price improvement.
     *
     * @param set The off-grid price improvement requirements active for this pool.
     * @param lowTick The lower tick index of the range order.
     * @param highTick The upper tick index of the range order.
     * @param liquidity The amount of liquidity in the range order.
     * @param gridSize The grid size associated with the pool in ticks.
     * @param priceTick The price tick of the current price in the pool.
     *
     * @return Returns false if the range is on-grid, and true if the range order
     *         is off-grid but eligible for price improvement. (If off-grid and 
     *         ineligible, the transaction will revert.) */
    function verifyFit(
        ImproveSettings memory set,
        int24 lowTick,
        int24 highTick,
        uint128 liquidity,
        uint16 gridSize,
        int24 priceTick
    ) internal pure returns (bool) {
        if (!isOnGrid(lowTick, highTick, gridSize)) {
            uint128 thresh = improveThresh(set, gridSize, priceTick, lowTick, highTick);
            require(liquidity >= thresh, "D");
            return true;
        }
        return false;
    }

    /* @notice Asserts that a given range order is on grid.
     * @param lowTick The lower tick index of the range order.
     * @param highTick The upper tick index of the range order.
     * @param gridSize The grid size associated with the pool in ticks. */
    function verifyFit(int24 lowTick, int24 highTick, uint16 gridSize) internal pure {
        require(isOnGrid(lowTick, highTick, gridSize), "D");
    }

    /* @notice Returns true if the boundaries of a range order occur on the tick grid.
     * @param lowerTick The lower tick index of the range order.
     * @param upperTick The upper tick index of the range order.
     * @param gridSize The grid size associated with the pool in ticks. */
    function isOnGrid(int24 lowerTick, int24 upperTick, uint16 gridSize) internal pure returns (bool) {
        int24 tickNorm = int24(uint24(gridSize));
        return lowerTick % tickNorm == 0 && upperTick % tickNorm == 0;
    }

    /* @notice Calculates the minimum liquidity required for a range order to be eligible
     *         for off-grid price improvement.
     * @param set The off-grid price improvement requirements active for this pool.
     * @param tickSize The size of the grid in tick granularity.
     * @param priceTick The price tick of the current price in the pool.
     * @param bidTick The lower tick index of the range order.
     * @param askTick The upper tick index of the range order.
     * @return The elibility threshold represented as newly minted liquidity. */
    function improveThresh(ImproveSettings memory set, uint16 tickSize, int24 priceTick, int24 bidTick, int24 askTick)
        internal
        pure
        returns (uint128)
    {
        require(bidTick < askTick);
        return canImprove(set, priceTick, bidTick, askTick)
            ? improvableThresh(set, tickSize, bidTick, askTick)
            : type(uint128).max;
    }

    /* @notice Calculated the liquidity threshold for price improvement, assuming that
     *    the order is eligible. */
    function improvableThresh(ImproveSettings memory set, uint16 tickSize, int24 bidTick, int24 askTick)
        private
        pure
        returns (uint128)
    {
        uint24 unitClip = clipInside(tickSize, bidTick, askTick);
        if (unitClip > 0) {
            return liqForClip(set, unitClip, bidTick);
        } else {
            uint24 bidWing = clipBelow(tickSize, bidTick);
            uint24 askWing = clipAbove(tickSize, askTick);
            return liqForWing(set, bidWing, bidTick) + liqForWing(set, askWing, askTick);
        }
    }

    /* @notice Calculates the liquidity threshold for a range where both boundaries
     *         are off grid. */
    function liqForClip(ImproveSettings memory set, uint24 wingSize, int24 refTick)
        private
        pure
        returns (uint128 liqDemand)
    {
        // If neither side is tethered to the grid the gas burden is twice as high
        // because there's two out-of-band crossings
        return 2 * liqForWing(set, wingSize, refTick);
    }

    /* @notice Calculates the liquidity threshold for a range where one boundary is
     *         off grid and one boundary is on grid. */
    function liqForWing(ImproveSettings memory set, uint24 wingSize, int24 refTick) private pure returns (uint128) {
        if (wingSize == 0) return 0;
        uint128 collateral = set.unitCollateral_;
        return convertToLiq(collateral, refTick, wingSize, set.inBase_);
    }

    /* @notice Given a range boundary determines the number of encompassed ticks
     *    that are off-grid. */
    function clipInside(uint16 tickSize, int24 bidTick, int24 askTick) internal pure returns (uint24) {
        require(bidTick < askTick);
        if (bidTick < 0 && askTick < 0) {
            return clipInside(tickSize, -askTick, -bidTick);
        } else if (bidTick < 0 && askTick >= 0) {
            return 0;
        } else {
            return clipNorm(uint24(tickSize), uint24(bidTick), uint24(askTick));
        }
    }

    /* @notice Determines off-grid tick size from a normalized range boundary that's
     *    safe for modular arithmetic. */
    function clipNorm(uint24 tickSize, uint24 bidTick, uint24 askTick) internal pure returns (uint24) {
        if (bidTick % tickSize == 0 || askTick % tickSize == 0) {
            return 0;
        } else if ((bidTick / tickSize) != (askTick / tickSize)) {
            return 0;
        } else {
            return askTick - bidTick;
        }
    }

    /* @notice Returns the number of off-grid ticks associated with the left side of
     *   a multi-grid spanning range order. */
    function clipBelow(uint16 tickSize, int24 bidTick) internal pure returns (uint24) {
        if (bidTick < 0) return clipAbove(tickSize, -bidTick);
        if (bidTick == 0) return 0;

        uint24 bidNorm = uint24(bidTick);
        uint24 tickNorm = uint24(tickSize);
        uint24 gridTick = ((bidNorm - 1) / tickNorm + 1) * tickNorm;
        return gridTick - bidNorm;
    }

    /* @notice Returns the number of off-grid ticks associated with the right side of
     *   a multi-grid spanning range order. */
    function clipAbove(uint16 tickSize, int24 askTick) internal pure returns (uint24) {
        if (askTick < 0) return clipBelow(tickSize, -askTick);

        uint24 askNorm = uint24(askTick);
        uint24 tickNorm = uint24(tickSize);
        uint24 gridTick = (askNorm / tickNorm) * tickNorm;
        return askNorm - gridTick;
    }

    /* We're converting from generalized collateral requirements to position-specific 
     * liquidity requirements. This is approximately the inversion of calculating 
     * collateral given liquidity. Therefore, we can just use the pre-existing CurveMath.
     * We're not worried about exact results in this context anyway. Remember this is
     * only being used to set an approximate economic threshold for allowing users to
     * add liquidity inside the grid. */
    function convertToLiq(uint128 collateral, int24 tick, uint24 wingSize, bool inBase)
        private
        pure
        returns (uint128)
    {
        uint128 priceTick = tick.getSqrtRatioAtTick();
        uint128 priceWing = (tick + int24(wingSize)).getSqrtRatioAtTick();
        return CurveMath.liquiditySupported(collateral, inBase, priceTick, priceWing);
    }

    /* @notice Returns true if the range order is within proximity to the curve's price
     *    tick enough to be eligible for off-grid price improvement. */
    function canImprove(ImproveSettings memory set, int24 priceTick, int24 bidTick, int24 askTick)
        private
        pure
        returns (bool)
    {
        if (set.unitCollateral_ == 0) return false;

        uint24 bidDist = diffTicks(bidTick, priceTick);
        uint24 askDist = diffTicks(priceTick, askTick);
        return bidDist <= set.awayTicks_ && askDist <= set.awayTicks_;
    }

    function diffTicks(int24 tickX, int24 tickY) private pure returns (uint24) {
        return tickY > tickX ? uint24(tickY - tickX) : uint24(tickX - tickY);
    }
}

/* @title Trade flow chaining library 
 * @notice Provides common conventions and utility functions for aggregating
 *   and backfilling the user <-> pool flow of token assets within a single
 *   pre-defined pair of assets. */
library Chaining {
    using SafeCast for int128;
    using SafeCast for uint128;
    using CurveMath for uint128;
    using TickMath for int24;
    using LiquidityMath for uint128;
    using CurveMath for CurveMath.CurveState;

    /* Used as an indicator code by long-form orders to indicate how a given sub-
     * directive should size relative to some pre-existing cumulative collateral flow
     * from all the actions on the pool.
     * evaluation of the long form order. Types supported:
     * 
     *    NO_ROLL_TYPE - No rolling fill. Evaluation will treat the set quantity as a 
     *        pre-fixed value in the native domain (i.e. tokens for swaps and liquidity 
     *        units for LP actions).
     *    
     *    ROLL_PASS_POS_TYPE - Rolling fill, but against a fixed token collateral target.
     *        Difference with NO_ROLL_TYPE, is the set quantity will denominate as the unit
     *        of the rolling quantity. I.e. represents token collateral instead of 
     *        liquidity units on LP actions.
     *
     *    ROLL_PASS_NEG_TYPE - Same as ROLL_PASS_POS_TYPE, but rolling quantity will be
     *                         negative.
     *
     *    ROLL_FRAC_TYPE - Fills a fixed-point fraction of the cumulatve rolling flow.
     *                     E.g. can swap 50% of the tokens returned from previous LP burn.
     *                     Denominated in fixed point basis points (1/10,000).
     *
     *    ROLL_DEBIT_TYPE - Fills the cumulative rolling flow with a fixed offset in the 
     *                      direction of user debit. E.g. can swap-buy all the tokens 
     *                      needed, plus slightly more.
     *
     *    ROLL_CREDIT_TYPE - Same as above, but offset in the direction of user credit.
     *                       E.g. can swap-sell all but X tokens from a previous burn 
     *                       operation.*/
    uint8 constant NO_ROLL_TYPE = 0;
    uint8 constant ROLL_PASS_POS_TYPE = 1;
    uint8 constant ROLL_PASS_NEG_TYPE = 2;
    uint8 constant ROLL_FRAC_TYPE = 4;
    uint8 constant ROLL_DEBIT_TYPE = 5;
    uint8 constant ROLL_CREDIT_TYPE = 6;

    /* @notice Common convention that defines the full execution context for 
     *   any arbitrary sequence of tradable actions (swap/mint/burn) within
     *   a single pool.
     * 
     * @param pool_ - The pre-queried specifications for the pool's market specs
     * @param improve_ - The pre-queries specification for off-grid price improvement
     *   requirements. (May be zero if user didn't request price improvement.)
     * @param roll_ - The base target to use for any quantities that are set as 
     *   open-ended rolling gaps. */
    struct ExecCntx {
        PoolSpecs.PoolCursor pool_;
        PriceGrid.ImproveSettings improve_;
        RollTarget roll_;
    }

    /* @notice In certain contexts CrocSwap provides the ability for the user to
    *     substitute pre-fixed quantity fields with empty "rolling" fields that are
    *     back-filled based on some cumulative flow across the execution. For example
    *     a swap may specify to buy however much of quote token was demanded by an
    *     earlier mint action on the pool. This struct provides the context for which 
    *     rolling flow to target if/when those back-fills are used.
    *
    *  @param inBaseQty_ If true, rolling quantity targets will use the cumulative
    *     flows on the base-side token in the pair. If false, will use the quote-side
    *     token flows.
    *  @param prePairBal_ Specifies a pre-set rolling flow offset to add/subtract to
    *     the cumulative flow within the pair. Useful for starting with a preset target
    *     from a previous pool or pair in the chain. */
    struct RollTarget {
        bool inBaseQty_;
        int128 prePairBal_;
    }

    /* @notice Represents the accumulated flow between user and pool within a transaction.
     * 
     * @param baseFlow_ Represents the cumulative base side token flow. Negative for
     *   flow going to the user, positive for flow going to the pool.
     * @param quoteFlow_ The cumulative quote side token flow.
     * @param baseProto_ The total amount of base side tokens being collected as protocol
     *   fees. The above baseFlow_ value is inclusive of this quantity.
     * @param quoteProto_ The total amount of quote tokens being collected as protocol
     *   fees. The above quoteFlow_ value is inclusive of this quantity. */
    struct PairFlow {
        int128 baseFlow_;
        int128 quoteFlow_;
        uint128 baseProto_;
        uint128 quoteProto_;
    }

    /* @notice Increments a PairFlow accumulator with a set of pre-determined flows.
     * @param flow The PairFlow object being accumulated. Function writes to this
     *   structure.
     * @param base The base side token flows. Negative when going to the user, positive
     *   for flows going to the pool.
     * @param quote The quote side token flows. Negative when going to the user, positive
     *   for flows going to the pool. */
    function accumFlow(PairFlow memory flow, int128 base, int128 quote) internal pure {
        flow.baseFlow_ += base;
        flow.quoteFlow_ += quote;
    }

    /* @notice Increments a PairFlow accumulator with the flows from another PairFlow
     *   object.
     * @param accum The PairFlow object being accumulated. Function writes to this
     *   structure.
     * @param flow The PairFlow input, whose flow is being added to the accumulator. */
    function foldFlow(PairFlow memory accum, PairFlow memory flow) internal pure {
        accum.baseFlow_ += flow.baseFlow_;
        accum.quoteFlow_ += flow.quoteFlow_;
        accum.baseProto_ += flow.baseProto_;
        accum.quoteProto_ += flow.quoteProto_;
    }

    /* @notice Increments a PairFlow accumulator with the flows from a swap leg.
     * @param flow The PairFlow object being accumulated. Function writes to this
     *   structure.
     * @param inBaseQty Whether the swap was denominated in base or quote side tokens.
     * @param base The base side token flows. Negative when going to the user, positive
     *   for flows going to the pool.
     * @param quote The quote side token flows. Negative when going to the user, positive
     *   for flows going to the pool.
     * @param proto The amount of protocol fees collected by the swap operation. (The
     *   total flows must be inclusive of this value). */
    function accumSwap(PairFlow memory flow, bool inBaseQty, int128 base, int128 quote, uint128 proto) internal pure {
        accumFlow(flow, base, quote);
        if (inBaseQty) {
            flow.quoteProto_ += proto;
        } else {
            flow.baseProto_ += proto;
        }
    }

    /* @notice Computes the amount of ambient liquidity to mint/burn in order to 
     *   neutralize the previously accumulated flow in the pair.
     *
     * @dev Note that because of integer rounding liquidity can't exactly neutralize
     *   a fixed flow of tokens. Therefore this function always rounds in favor of 
     *   leaving the user with a very small collateral credit. With a credit they can
     *   use the dust discard feature at settlement to avoid any token transfer.
     *
     * @param roll Indicates the context for the type of roll target that the call 
     *   should target. (See RollTarget struct above.)
     * @param dir The ambient liquidity directive the liquidity is applied to
     * @param curve The liquidity curve that is being minted or burned against.
     * @param flow The previously accumulated flow on this pair. Based on the context 
     *   above, this function will target the accumulated flow contained herein.
     * 
     * @return liq The amount of ambient liquidity to mint/burn to meet the target.
     * @return isAdd If true, then liquidity must be minted to neutralize rolling flow,
     *   If false, then liquidity must be burned. */
    function plugLiquidity(
        RollTarget memory roll,
        Directives.AmbientDirective memory dir,
        CurveMath.CurveState memory curve,
        PairFlow memory flow
    ) internal pure {
        if (dir.rollType_ != NO_ROLL_TYPE) {
            (uint128 collateral, bool isAdd) = collateralDemand(roll, flow, dir.rollType_, dir.liquidity_);

            uint128 liq = sizeAmbientLiq(collateral, isAdd, curve.priceRoot_, roll.inBaseQty_);
            (dir.liquidity_, dir.isAdd_) = (liq, isAdd);
        }
    }

    /* @notice Computes the amount of concentrated liquidity to mint/burn in order to 
     *   neutralize the previously accumulated flow in the pair.
     *
     * @dev Note that concentrated liquidity is represented as lots 1024. The results of
     *   this function will always conform to that multiple. Because of integer rounding
     *   it's impossible to guarantee a liquidity value that exactly neutralizes an 
     *   arbitrary token flow quantity. Therefore this function always rounds in favor of 
     *   leaving the user with a very small collateral credit. With a credit they can
     *   use the dust discard feature at settlement to avoid any token transfer.
     *
     * @param roll Indicates the context for the type of roll target that the call 
     *   should target. (See RollTarget struct above.)
     * @param bend The concentrated range order directive the liquidity is applied to
     * @param curve The liquidity curve that is being minted or burned against.
     * @param flow The previously accumulated flow on this pair. Based on the context 
     *   above, this function will target the accumulated flow contained herein.
     * @param lowTick The tick index of the lower bound of the concentrated liquidity
     * @param highTick The tick index of the upper bound of the concentrated liquidity
     * 
     * @return seed The amount of ambient liquidity seeds to mint/burn to meet the
     *   target. 
     * @return isAdd If true, then liquidity must be minted to neutralize rolling flow,
     *   If false, then liquidity must be burned. */
    function plugLiquidity(
        RollTarget memory roll,
        Directives.ConcentratedDirective memory bend,
        CurveMath.CurveState memory curve,
        int24 lowTick,
        int24 highTick,
        PairFlow memory flow
    ) internal pure {
        if (bend.rollType_ == NO_ROLL_TYPE) return;

        (uint128 collateral, bool isAdd) = collateralDemand(roll, flow, bend.rollType_, bend.liquidity_);
        uint128 liq = sizeConcLiq(collateral, isAdd, curve.priceRoot_, lowTick, highTick, roll.inBaseQty_);
        (bend.liquidity_, bend.isAdd_) = (liq, isAdd);
    }

    /* @notice Calculates the amount of ambient liquidity that a fixed amount of token
     *         collateral maps to into the the pool.
     *
     * @dev Will always round liquidity conservatively. That is when being used in an add
     *      liquidity context, user can be assured that the liquidity requires slightly
     *      less than their collateral commitment. And when liquidity is being removed
     *      collateral will be slightly higher for the amount of removed liquidity.
     * 
     * @param collateral The amount of collateral (either base of quote) tokens that we
     *                   want to size liquidity for.
     * @param isAdd Indicates whether the liquidity is being added or removed. Necessary
     *              to make sure that we round conservatively.
     * @param priceRoot The current price in the pool.
     * @param inBaseQty True if the collateral is a base token value, false if quote 
     *                  token.
     * @return The amount of liquidity, in sqrt(X*Y) units, supported by this 
     *         collateral. */
    function sizeAmbientLiq(uint128 collateral, bool isAdd, uint128 priceRoot, bool inBaseQty)
        internal
        pure
        returns (uint128)
    {
        uint128 liq = bufferCollateral(collateral, isAdd).liquiditySupported(inBaseQty, priceRoot);
        return isAdd ? liq : (liq + 1);
    }

    /* @notice Same as sizeAmbientLiq() (see above), but calculates for concentrated 
     *         liquidity in a given range.
     * 
     * @param collateral The amount of collateral (either base of quote) tokens that we
     *                   want to size liquidity for.
     * @param isAdd Indicates whether the liquidity is being added or removed. Necessary
     *              to make sure that we round conservatively.
     * @param priceRoot The current price in the pool.
     * @param lowTick The tick index of the lower bound of the concentrated liquidity 
     *                range.
     * @param highTick The tick index of the upper bound.
     * @param inBaseQty True if the collateral is a base token value, false if quote 
     *                  token.
     * @return The amount of concentrated liquidity (in sqrt(X*Y) units) supported in
     *         the given tick range. */
    function sizeConcLiq(
        uint128 collateral,
        bool isAdd,
        uint128 priceRoot,
        int24 lowTick,
        int24 highTick,
        bool inBaseQty
    ) internal pure returns (uint128) {
        (uint128 bidPrice, uint128 askPrice) = determinePriceRange(priceRoot, lowTick, highTick, inBaseQty);

        uint128 liq = bufferCollateral(collateral, isAdd).liquiditySupported(inBaseQty, bidPrice, askPrice);

        return isAdd ? liq.shaveRoundLots() : liq.shaveRoundLotsUp();
    }

    // Represents a small, economically meaningless amount of token wei that makes sure
    // we're always leaving the user with a collateral credit.
    function bufferCollateral(uint128 collateral, bool isAdd) private pure returns (uint128) {
        uint128 BUFFER_COLLATERAL = 4;

        if (isAdd) {
            // This ternary switch always produces non-negative result, preventing underflow
            return collateral < BUFFER_COLLATERAL ? 0 : collateral - BUFFER_COLLATERAL;
        } else {
            // This ternary switch prevents buffering into an overflow
            return collateral > type(uint128).max - 4 ? type(uint128).max : collateral + BUFFER_COLLATERAL;
        }
    }

    /* @notice Converts a swap that's indicated to be a rolling gap-fill into one
     *   with quantity and direction set to neutralize hitherto accumulated rolling
     *   flow. E.g. if the user previously performed a buy swap, this would output
     *   a sell swap with an exactly opposite quantity.
     *
     * @param roll Indicates the context for the type of roll target that the call 
     *   should target. (See RollTarget struct above.)
     * @param swap The templated SwapDirective object. This function will update the
     *   object with the quantity, direction, and (if necessary) price needed to gap-fill
     *   the rolling flow accumulator.
     * @param flow The previously accumulated flow on this pair. Based on the context 
     *   above, this function will target the accumulated flow contained herein. */
    function plugSwapGap(RollTarget memory roll, Directives.SwapDirective memory swap, PairFlow memory flow)
        internal
        pure
    {
        if (swap.rollType_ != NO_ROLL_TYPE) {
            int128 plugQty = scaleRoll(roll, flow, swap.rollType_, swap.qty_);
            overwriteSwap(swap, plugQty);
        }
    }

    /* This function will overwrite the swap directive template to plug the
     * rolling qty. This obviously involves writing the swap quantity. It
     * may also possibly flip the swap direction, which is useful in certain
     * complex scenarios where the user can't exactly predict the direction'
     * of the roll.
     *
     * If rolling plug flips the swap direction, then the limit price will
     * be set in the wrong direction and the trade will fail. In this case
     * we disable limitPrice. This is fine because rolling swaps are only
     * used in the composite code path, where the user can set their output
     * limits at the settle layer. */
    function overwriteSwap(Directives.SwapDirective memory swap, int128 rollQty) private pure {
        bool prevDir = swap.isBuy_;
        swap.isBuy_ = swap.inBaseQty_ ? (rollQty < 0) : (rollQty > 0);
        swap.qty_ = rollQty > 0 ? uint128(rollQty) : uint128(-rollQty);

        if (prevDir != swap.isBuy_) {
            swap.limitPrice_ = swap.isBuy_ ? TickMath.MAX_SQRT_RATIO : TickMath.MIN_SQRT_RATIO;
        }
    }

    /* @notice Calculates the total amount of collateral and its direction, that we should
     *   be targeting to neutralize when sizing a liquidity gap-fill. */
    function collateralDemand(RollTarget memory roll, PairFlow memory flow, uint8 rollType, uint128 nextQty)
        private
        pure
        returns (uint128 collateral, bool isAdd)
    {
        int128 collatFlow = scaleRoll(roll, flow, rollType, nextQty);

        isAdd = collatFlow < 0;
        collateral = collatFlow > 0 ? uint128(collatFlow) : uint128(-collatFlow);
    }

    /* @notice Calculates the effective bid/ask committed collateral range related
     *   to a concentrated liquidity range order. The calculation is different depending on
     *   whether the curve price is inside or outside the specified tick range. (See below) */
    function determinePriceRange(uint128 curvePrice, int24 lowTick, int24 highTick, bool inBase)
        private
        pure
        returns (uint128 bidPrice, uint128 askPrice)
    {
        bidPrice = lowTick.getSqrtRatioAtTick();
        askPrice = highTick.getSqrtRatioAtTick();

        /* The required reserve collateral for a range order is a function of whether
         * the order is in-range or out-of-range. For in range orders the reserves are
         * determined based on the distance between the current price and range boundary
         * price:
         *           Lower range        Curve Price        Upper range
         *                |                  |                  | 
         *    <-----------*******************O*******************------------->
         *                --------------------
         *                 Base token reserves
         *
         * For out of range orders the reserve collateral is a function of the entire
         * width of the range.
         *
         *           Lower range              Upper range       Curve Price
         *                |                        |                 |
         *    <-----------**************************-----------------O---->
         *                --------------------------
         *                   Base token reserves
         *
         * And if the curve is out of range on the opposite side, the reserve collateral
         * would be zero, and therefore it's impossible to map a non-zero amount of tokens
         * to liquidity (and function reverts)
         *
         *        Curve Price          Lower range              Upper range       
         *           |                     |                        |                 
         *    <------O---------------------**************************---------------------->
         *                                      ZERO base tokens
         */
        if (curvePrice <= bidPrice) {
            require(!inBase);
        } else if (curvePrice >= askPrice) {
            require(inBase);
        } else if (inBase) {
            askPrice = curvePrice;
        } else {
            bidPrice = curvePrice;
        }
    }

    /* @notice Sums the total rolling balance that should be targeted to be neutralized.
     *   Includes both the accumulated flow in the pair and the pre-pair starting balance
     *   set in the RollTarget context (if any). */
    function totalBalance(RollTarget memory roll, PairFlow memory flow) private pure returns (int128) {
        int128 pairFlow = (roll.inBaseQty_ ? flow.baseFlow_ : flow.quoteFlow_);
        return roll.prePairBal_ + pairFlow;
    }

    /* @notice Given a cumulative rolling flow, calculates a gap-fill quantity based on
     *         rolling target parameters.
     *
     * @param roll The rolling target schematic, set at the begining of the pair hop.
     * @param flow The cumulative collateral flow accumulated in this pair hop so far.
     * @param rollType The type of rolling gap-fill to target (see indicator comments 
     *                 above)
     * @param target   The rolling gap-fill target, contextualized by rollType value.
     * @return         The size optimally scaled to match the rolling gap-fill target. */
    function scaleRoll(RollTarget memory roll, PairFlow memory flow, uint8 rollType, uint128 target)
        private
        pure
        returns (int128)
    {
        int128 rollGap = totalBalance(roll, flow);
        return scalePlug(rollGap, rollType, target);
    }

    /* @notice Given a fixed rolling gap, scales the next incremental size to achieve
     *         a specific user-defined target.
     *
     * @param rollGap The rolling gap that exists prior to this leg of the long-form order.
     * @param rollType The type of rolling gap-fill to target (see indicator comments 
     *                 above)
     * @param target   The rolling gap-fill target, contextualized by rollType value.
     * @return         The size optimally scaled to match the rolling gap-fill target. */
    function scalePlug(int128 rollGap, uint8 rollType, uint128 target) private pure returns (int128) {
        if (rollType == ROLL_PASS_POS_TYPE) {
            return int128(target);
        } else if (rollType == ROLL_PASS_NEG_TYPE) {
            return -int128(target);
        } else if (rollType == ROLL_FRAC_TYPE) {
            return int128(int256(rollGap) * int256(int128(target)) / 10000);
        } else if (rollType == ROLL_DEBIT_TYPE) {
            return rollGap + int128(target);
        } else {
            return rollGap - int128(target);
        }
    }

    /* @notice Convenience function to round up flows pinned to liquidity. Will safely 
     *         (i.e. only in the debit direction) round up the flow to the user-specified
     *         qty. This is primarily useful for mints where the user specifies a token 
     *         qty, that gets cast to liquidity, that then gets converted back to
     *         a token quantity amount. Because of fixed-point rounding the latter will
     *         be slightly smaller than the fixed specified amount. For usability and gas
     *         optimization the user will likely want to just pay the full amount. */
    function pinFlow(int128 baseFlow, int128 quoteFlow, uint128 uQty, bool inBase)
        internal
        pure
        returns (int128, int128)
    {
        int128 qty = uQty.toInt128Sign();
        if (inBase && int128(qty) > baseFlow) {
            baseFlow = int128(qty);
        } else if (!inBase && int128(qty) > quoteFlow) {
            quoteFlow = int128(qty);
        }
        return (baseFlow, quoteFlow);
    }
}

/* @title Token flow library
 * @notice Provides a facility for joining token flows for trades that occur on an 
 *         arbitrary long chain of overlapping pairs. */
library TokenFlow {
    /* @notice Represents the current hop within a chain of pair hops.
     * @param baseToken_ The base token in the current pair. (If zero native Ethereum)
     * @param quoteToken_ The quote token in the current pair.
     * @param isBaseFront_ If true, then the base side of the pair represents the entry
     *                     token on this hop in the chain.
     * @param legFlow_ - Represents the total flow from the exit side on the previous pair
     *                   hop in the chain.
     * @param flow_ - Accumulator to collect the flow on this pair hop. */
    struct PairSeq {
        address baseToken_;
        address quoteToken_;
        bool isBaseFront_;
        int128 legFlow_;
        Chaining.PairFlow flow_;
    }

    /* @notice Moves the PairSeq cursor object onto the next pair in a hop.
     *
     * @dev    Note that this doesn't process, roll or reset flows. All of the 
     *         bookkeeping related to this and settlement should be done *before* calling
     *         this on the next pair. 
     *
     * @param seq The cursor object, pair tokens will be updated after call.
     * @param tokenFront The token associated with the front or entry of the chain's 
     *                   next pair hop.
     * @param tokenBack The token associated with the back or exit of the chain's 
     *                  next pair hop. */
    function nextHop(PairSeq memory seq, address tokenFront, address tokenBack) internal pure {
        seq.isBaseFront_ = tokenFront < tokenBack;
        if (seq.isBaseFront_) {
            seq.baseToken_ = tokenFront;
            seq.quoteToken_ = tokenBack;
        } else {
            seq.quoteToken_ = tokenFront;
            seq.baseToken_ = tokenBack;
        }
    }

    /* @notice Returns the token at the front/entry side of the pair hop. */
    function frontToken(PairSeq memory seq) internal pure returns (address) {
        return seq.isBaseFront_ ? seq.baseToken_ : seq.quoteToken_;
    }

    /* @notice Returns the token at the back/exit side of the pair hop. */
    function backToken(PairSeq memory seq) internal pure returns (address) {
        return seq.isBaseFront_ ? seq.quoteToken_ : seq.baseToken_;
    }

    /* @notice Called when all the flows have been tallied and finalized for this
     *         pair hop in the chain. Resets and rolls the object and returns the net
     *         flows to be settled between user and exchange.
     *
     * @param seq The PairSeq cursor object. Aftering calling the object will be updated 
     *            to have the back/exit flow rolled into the leg for the next hop, and 
     *            the previous accumulators will be reset.
     *
     * @return clippedFlow The net flow (inclusive of the rolled leg flow from the 
     *                     previous hop) on the front/entry side of the pair to be 
     *                     settled. Negative indicates credit from dex to user, positive
     *                     indicates debit from user to dex.*/
    function clipFlow(PairSeq memory seq) internal pure returns (int128 clippedFlow) {
        (int128 frontAccum, int128 backAccum) =
            seq.isBaseFront_ ? (seq.flow_.baseFlow_, seq.flow_.quoteFlow_) : (seq.flow_.quoteFlow_, seq.flow_.baseFlow_);

        clippedFlow = seq.legFlow_ + frontAccum;
        seq.legFlow_ = backAccum;

        seq.flow_.baseFlow_ = 0;
        seq.flow_.quoteFlow_ = 0;
        seq.flow_.baseProto_ = 0;
        seq.flow_.quoteProto_ = 0;
    }

    /* @notice Returns the final flow to be settled associated with the closing leg at 
     *         the end of the chain of pair hops. Negative means credit from dex to user.
     *         Positive is debit from user to dex. */
    function closeFlow(PairSeq memory seq) internal pure returns (int128) {
        return seq.legFlow_;
    }

    /* @notice If true, indicates that the asset-specifying address represents native 
     *         Ethereum. Otherwise it should be the valid address of the ERC20 token 
     *         tracker. */
    function isEtherNative(address token) internal pure returns (bool) {
        return token == address(0);
    }
}

/* @title Curve fee assimilation library
 * @notice Provides functionality for incorporating arbitrary token fees into
 *         a locally stable constant-product liquidity curve. */
library CurveAssimilate {
    using LiquidityMath for uint128;
    using CompoundMath for uint128;
    using CompoundMath for uint64;
    using SafeCast for uint256;
    using FixedPoint for uint128;
    using CurveMath for CurveMath.CurveState;

    /* @notice Converts token-based fees into ambient liquidity on the curve,
     *         adjusting the price accordingly.
     * 
     * @dev The user is responsible to make sure that the price shift will never
     *      exceed the locally stable range of the liquidity curve. I.e. that
     *      the price won't cross a book level bump. Because fees are only a tiny
     *      fraction of swap notional, the best approach is to only collect fees
     *      on the segment of the notional up to the level bump price limit. If
     *      a swap spans multiple bumps, then call this function separtely on a
     *      per-segment basis.
     *
     * @param curve  The pre-assimilated state of the consant-product AMM liquidity
     *    curve. This in memory structure will be updated to reflect the impact of 
     *    the assimilation.
     * @param feesPaid  The pre-calculated fees to be collected and incorporated
     *    as liquidity into the curve. Must be denominated (and colleted) on the
     *    opposite pair side as the swap denomination.
     * @param isSwapInBase  Set to true, if the swap is denominated in the base
     *    token of the pair. (And therefore fees are denominated in quote token) */
    function assimilateLiq(CurveMath.CurveState memory curve, uint128 feesPaid, bool isSwapInBase) internal pure {
        // In zero liquidity curves, it makes no sense to assimilate, since
        // it will run prices to infinity.
        uint128 liq = CurveMath.activeLiquidity(curve);
        if (liq == 0) return;

        bool feesInBase = !isSwapInBase;
        uint128 feesToLiq = shaveForPrecision(liq, curve.priceRoot_, feesPaid, feesInBase);
        uint64 inflator = calcLiqInflator(liq, curve.priceRoot_, feesToLiq, feesInBase);

        if (inflator > 0) {
            stepToLiquidity(curve, inflator, feesInBase);
        }
    }

    /* @notice Converts a fixed fee collection into a constant product liquidity
     *         multiplier.
     * @dev    To be conservative, every fixed point calculation step rounds down.
     *         Because of this the result can be an arbitrary epsilon smaller than
     *         the real formula.
     * @return The imputed percent growth to aggregate liquidity resulting from 
     *         assimilating these fees into the virtual reserves. Represented as
     *         Q16.48 fixed-point, where the result G is used as a (1+G) multiplier. */
    function calcLiqInflator(uint128 liq, uint128 price, uint128 feesPaid, bool inBaseQty)
        private
        pure
        returns (uint64)
    {
        // First calculate the virtual reserves at the curve's current price...
        uint128 reserve = CurveMath.reserveAtPrice(liq, price, inBaseQty);

        // ...Then use that to calculate how much the liqudity would grow assuming the
        // fees were added as reserves into an equivalent constant-product AMM curve.
        return calcReserveInflator(reserve, feesPaid);
    }

    /* @notice Converts a fixed delta change in the virtual reserves to a percent 
     *         change in the AMM curve's active liquidity.
     *
     * @dev Inflators above will 100% result in reverted transactions. */
    function calcReserveInflator(uint128 reserve, uint128 feesPaid) private pure returns (uint64 inflator) {
        // Short-circuit when virtual reserves are smaller than fees. This can only
        // occur when liquidity is extremely small, and so is economically
        // meanignless. But guarantees numerical stability.
        if (reserve == 0 || feesPaid > reserve) return 0;

        uint128 nextReserve = reserve + feesPaid;
        uint64 inflatorRoot = nextReserve.compoundDivide(reserve);

        // Since Liquidity is represented as Sqrt(X*Y) the growth rate of liquidity is
        // Sqrt(X'/X) where X' = X + delta(X)
        inflator = inflatorRoot.approxSqrtCompound();

        // Important. The price precision buffer calcualted in assimilateLiq assumes
        // liquidity will never expand by a factor of 2.0 (i.e. inflator over 1.0 in
        // Q16.48). See the shaveForPrecision() function comments for more discussion
        require(inflator < FixedPoint.Q48, "IF");
    }

    /* @notice Adjusts the fees assimilated into the liquidity curve. This is done to
     *    hold out a small amount of collateral that doesn't expand the liquidity
     *    in the curve. That's necessary so we have slack in the virtual reserves to
     *    prevent under-collateralization resulting from fixed point precision rounding
     *    on the price shift. 
     *    
     * @dev Price can round up to one precision unit (2^-64) away from the true real
     *    value. Therefore we have to over-collateralize the existing liquidity by
     *    enough to buffer the virtual reserves by this amount. Economically this is 
     *    almost always a meaningless amount. Often just 1 wei (rounded up) for all but
     *    the biggest or most extreme priced curves. 
     *
     * @return The amount of reward fees available to assimilate into the liquidity
     *    curve after deducting the precision over-collaterilization allocation. */
    function shaveForPrecision(uint128 liq, uint128 price, uint128 feesPaid, bool isFeesInBase)
        private
        pure
        returns (uint128)
    {
        // The precision buffer is calculated on curve precision, before curve liquidity
        // expands from fee assimilation. Therefore we upper bound the precision buffer to
        // account for maximum possible liquidity expansion.
        //
        // We set a factor of 2.0, as the bound because that would represnet swap fees
        // in excess of the entire virtual reserve of the curve. This still allows any
        // size impact swap (because liquidity fees cannot exceed 100%). The only restrction
        // is extremely large swaps where fees are collected in input tokens (i.e. fixed
        // output swaps)
        //
        // See the require statement calcReserveInflator function, for where this check
        // is enforced.
        uint128 MAX_LIQ_EXPANSION = 2;

        uint128 bufferTokens = MAX_LIQ_EXPANSION * CurveMath.priceToTokenPrecision(liq, price, isFeesInBase);
        unchecked {
            return feesPaid <= bufferTokens ? 0 : feesPaid - bufferTokens; // Condition assures never underflow
        }
    }

    /* @notice Given a targeted aggregate liquidity inflator, affects that change in
     *    the curve object by expanding the ambient seeds, and adjusting the cumulative
     *    growth accumulators as needed. 
     *
     * @dev To be conservative, a number of fixed point calculations will round down 
     *    relative to the exact mathematical liquidity value. This is to prevent 
     *    under-collateralization from over-expanding liquidity relative to virtual 
     *    reserves available to the pool. This means the curve's liquidity grows slightly
     *    less than mathematical exact calculation would imply. 
     *
     * @dev    Price is always rounded further in the direction of the shift. This 
     *         shifts the collateralization burden in the direction of the fee-token.
     *         This makes sure that the opposite token's collateral requirements is
     *         unchanged. The fee token should be sufficiently over-collateralized from
     *         a previous adjustment made in shaveForPrecision()
     *
     * @param curve The current state of the liquidity curve, will be updated to reflect
     *              the assimilated liquidity from fee accumulation.
     * @param inflator The incremental growth in total curve liquidity contributed by this
     *                 swaps paid fees.
     * @param feesInBase If true, indicates swap paid fees in base token. */
    function stepToLiquidity(CurveMath.CurveState memory curve, uint64 inflator, bool feesInBase) private pure {
        curve.priceRoot_ = CompoundMath.compoundPrice(curve.priceRoot_, inflator, feesInBase);

        // The formula for Liquidity is
        //     L = A + C
        //       = S * (1 + G) + C
        //   (where A is ambient liqudity, S is ambient seeds, G is ambient growth,
        //    and C is conc. liquidity)
        //
        // Liquidity growth is distributed pro-rata, between the ambient and concentrated
        // terms. Therefore ambient-side growth is reflected by inflating the growth rate:
        //    A' = A * (1 + I)
        //       = S * (1 + G) * (1 + I)
        //   (where A' is the post transaction ambient liquidity, and I is the liquidity
        //    inflator for this transaction)
        //
        // Note that if the deflator reaches its maximum value (equivalent to 2^16), then
        // this value will cease accumulating new rewards. Essentially all fees attributable
        // to ambient liquidity will be burned. Economically speaking, this is unlikely to happen
        // for any meaningful pool, but be aware. See the Ambient Rewards section of the
        // documentation at docs/CurveBound.md in the repo for more discussion.
        curve.seedDeflator_ = curve.seedDeflator_.compoundStack(inflator);

        // Now compute the increase in ambient seed rewards to concentrated liquidity.
        // Rewards stored as ambient seeds, but collected in the form of liquidity:
        //    Ar = Sr * (1 + G)
        //    Sr = Ar / (1 + G)
        //  (where Ar are concentrated rewards in ambient liquidity, and Sr are
        //   concentrated rewards denominated in ambient seeds)
        //
        // Note that there's a minor difference from using the post-inflated cumulative
        // ambient growth (G) calculated in the previous step. This rounds the rewards
        // growth down, which increases numerical over-collateralization.

        // Concentrated rewards are represented as a rate of per unit ambient growth
        // in seeds. Therefore to calculate the marginal increase in concentrated liquidity
        // rewards we deflate the marginal increase in total liquidity by the seed-to-liquidity
        // deflator
        uint64 concRewards = inflator.compoundShrink(curve.seedDeflator_);

        // Represents the total number of new ambient liquidity seeds that are created from
        // the swap fees accumulated as concentrated liquidity rewards. (All concentrated rewards
        // are converted to ambient seeds.) To calculate we take the marginal increase in concentrated
        // rewards on this swap and multiply by the total amount of active concentrated liquidity.
        uint128 newAmbientSeeds = uint256(curve.concLiq_.mulQ48(concRewards)).toUint128();

        // To be conservative in favor of over-collateralization, we want to round down the marginal
        // rewards.
        curve.concGrowth_ += roundDownConcRewards(concRewards, newAmbientSeeds);
        curve.ambientSeeds_ += newAmbientSeeds;
    }

    /* @notice To avoid over-promising rewards, we need to make sure that fixed-point
     *   rounding effects don't round concentrated rewards growth more than ambient 
     *   seeds. Otherwise we could possibly reach a situation where burned rewards 
     *   exceed the the ambient seeds stored on the curve.
     *
     * @dev Functionally, the reward inflator is most likely higher precision than
     *   the ambient seed injection. Therefore prevous fixed point math that rounds
     *   down both could over-promise rewards realtive to backed seeds. To correct
     *   for this, we have to shrink the rewards inflator by the precision unit's 
     *   fraction of the ambient injection. Thus guaranteeing that the adjusted rewards
     *   inflator under-promises relative to backed seeds. */
    function roundDownConcRewards(uint64 concInflator, uint128 newAmbientSeeds) private pure returns (uint64) {
        // No need to round down if the swap was too small for concentrated liquidity
        // to earn any rewards.
        if (newAmbientSeeds == 0) return 0;

        // We always want to make sure that the rewards accumulator is conservatively
        // rounded down relative to the actual liquidity being added to the curve.
        //
        // To shrink the rewards by ambient round down precision we use the formula:
        // R' = R * A / (A + 1)
        //   (where R is the rewards inflator, and A is the ambient seed injection)
        //
        // Precision wise this all fits in 256-bit arithmetic, and is guaranteed to
        // cast to 64-bit result, since the result is always smaller than the original
        // inflator.
        return uint64(uint256(concInflator) * uint256(newAmbientSeeds) / uint256(newAmbientSeeds + 1));
    }
}

/* @title Curve roll library
 * @notice Provides functionality for rolling swap flows onto a constant-product
 *         AMM liquidity curve. */
library CurveRoll {
    using SafeCast for uint256;
    using SafeCast for uint128;
    using LiquidityMath for uint128;
    using CompoundMath for uint256;
    using CurveMath for CurveMath.CurveState;
    using CurveMath for uint128;

    /* @notice Applies a given flow onto a constant product AMM curve, adjusts the curve
     *   price, and outputs accumulator deltas on both sides.
     *
     * @dev Note that this function does *NOT* check whether the curve is liquidity 
     *   stable through the flow impact. It's the callers job to make sure that the 
     *   impact doesn't cross through any tick barrier that knocks concentrated liquidity
     *   in/out. 
     *
     * @param curve - The current state of the active liquidity curve. After calling
     *   this struct will be updated with the post-swap price. Note that none of the
     *   fee accumulator fields are adjusted. This function does *not* collect or apply
     *   liquidity fees. It's the callers responsibility to handle fees outside this
     *   call.
     * @param flow - The amount of tokens to swap on this leg. In certain cases this 
     *   number may be a fixed point estimate based on a price target. Collateral safety
     *   is guaranteed with up to 2 wei of precision loss.
     * @param inBaseQty - If true, the above flow applies to the base-side tokens in the
     *                    pair. If false, applies to the quote-side tokens.
     * @param isBuy - If true, the flows are paying base tokens to the pool and receiving
     *                quote tokens. (Hence pushing the price up.) If false, vice versa.
     * @param swapQty - The total quantity left on the swap across all legs. May or may
     *                  not be equal to flow, or could be left depending on whether this
     *                  leg will fill the entire quantity.
     *
     * @return baseFlow - The signed flow of the base-side tokens. Negative means the flow
     *              is being paid from the pool to the user. Positive means the flow is
     *              being paid from the user to the pool.
     * @return quoteFlow - The signed flow of the quote-side tokens.
     * @return qtyLeft - The amount of swapQty remaining after the flow from this leg is
     *                   processed. */
    function rollFlow(CurveMath.CurveState memory curve, uint128 flow, bool inBaseQty, bool isBuy, uint128 swapQty)
        internal
        pure
        returns (int128, int128, uint128)
    {
        (uint128 counterFlow, uint128 nextPrice) = deriveImpact(curve, flow, inBaseQty, isBuy);
        (int128 paidFlow, int128 paidCounter) = signFlow(flow, counterFlow, inBaseQty, isBuy);
        return setCurvePos(curve, inBaseQty, isBuy, swapQty, nextPrice, paidFlow, paidCounter);
    }

    /* @notice Moves a curve to a pre-determined price target, and calculates the flows
     *   as necessary to reach the target. The final curve will end at exactly that price
     *   and the flows are set to guarantee incremental collateral safety.
     *
     * @dev Note that this function does *NOT* check whether the curve is liquidity 
     *   stable through the swap impact. It's the callers job to make sure that the 
     *   impact doesn't cross through any tick barrier that knocks concentrated liquidity
     *   in/out. 
     *
     * @param curve - The current state of the active liquidity curve. After calling
     *   this struct will be updated with the post-swap price. Note that none of the
     *   fee accumulator fields are adjusted. This function does *not* collect or apply
     *   liquidity fees. It's the callers responsibility to handle fees outside this
     *   call.
     * @param price - The target limit price that the curve is being rolled to. Defined
     *                as Q64.64 fixed point.
     * @param inBaseQty - If true, the above flow applies to the base-side tokens in the
     *                    pair. If false, applies to the quote-side tokens.
     * @param isBuy - If true, the flows are paying base tokens to the pool and receiving
     *                quote tokens. (Hence pushing the price up.) If false, vice versa.
     * @param swapQty - The total quantity left on the swap across all legs. May or may
     *                  not be equal to flow, or could be left depending on whether this
     *                  leg will fill the entire quantity.
     *
     * @return baseFlow - The signed flow of the base-side tokens. Negative means the flow
     *              is being paid from the pool to the user. Positive means the flow is
     *              being paid from the user to the pool.
     * @return quoteFlow - The signed flow of the quote-side tokens.
     * @return qtyLeft - The amount of swapQty remaining after the flow from this leg is
     *                   processed. */
    function rollPrice(CurveMath.CurveState memory curve, uint128 price, bool inBaseQty, bool isBuy, uint128 swapQty)
        internal
        pure
        returns (int128, int128, uint128)
    {
        (uint128 flow, uint128 counterFlow) = deriveDemand(curve, price, inBaseQty);
        (int128 paidFlow, int128 paidCounter) = signFixed(flow, counterFlow, inBaseQty, isBuy);
        return setCurvePos(curve, inBaseQty, isBuy, swapQty, price, paidFlow, paidCounter);
    }

    /* @notice Called when a curve has reached its a  bump barrier. Because the 
     *   barrier occurs at the final price in the tick, we need to "shave the price"
     *   over into the next tick. The curve has kicked in liquidity that's only active
     *   below this price, and we need the price to reflect the correct tick. So we burn
     *   an economically meaningless amount of collateral token wei to shift the price 
     *   down by exactly one unit of precision into the next tick. */
    function shaveAtBump(CurveMath.CurveState memory curve, bool inBaseQty, bool isBuy, uint128 swapLeft)
        internal
        pure
        returns (int128, int128, uint128)
    {
        uint128 burnDown = CurveMath.priceToTokenPrecision(curve.activeLiquidity(), curve.priceRoot_, inBaseQty);
        require(swapLeft > burnDown, "BD");

        if (isBuy) {
            return setShaveUp(curve, inBaseQty, burnDown);
        } else {
            return setShaveDown(curve, inBaseQty, burnDown);
        }
    }

    /* @notice After calculating a burn down amount of collateral, roll the curve over
     *         into the next tick below the current tick. 
     *
     * @dev    This is used to handle the situation when we've reached the end of a liquidity
     *         range, and need to safely move the curve by one price unit to move it over into
     *         the next liquidity range. Although a single price unit is almost always economically
     *         de minims, there are small flows needed to move the curve price while remaining safely
     *         over-collateralized.
     *
     * @param curve The liquidity curve, which will be adjusted to move the price one unit.
     * @param inBaseQty If true indicates that the swap is made with fixed base tokens and floating quote
     *                  tokens.
     * @param burnDown The pre-calculated amount of tokens needed to maintain over-collateralization when
     *                 moving the curve by one price unit.
     * 
     * @return paidBase The additional amount of base tokens that the swapper should pay to the curve to
     *                  move the price one unit.
     * @return paidQuote The additional amount of quote tokens the swapper should pay to the curve.
     * @return burnSwap  The amount of tokens to remove from the remaining fixed leg of the swap quantity. */
    function setShaveDown(CurveMath.CurveState memory curve, bool inBaseQty, uint128 burnDown)
        private
        pure
        returns (int128 paidBase, int128 paidQuote, uint128 burnSwap)
    {
        unchecked {
            if (curve.priceRoot_ > TickMath.MIN_SQRT_RATIO) {
                curve.priceRoot_ -= 1; // MIN_SQRT is well above uint128 0
            }

            // When moving the price down at constant liquidity, no additional base tokens are required for
            // collateralization
            paidBase = 0;

            // When moving the price down at constant liquidity, the swapper must pay a small amount of additional
            // quote tokens to keep the curve over-collateralized.
            paidQuote = burnDown.toInt128Sign();

            // If the fixed swap leg is in base tokens, then this has zero impact, if the swap leg is in quote
            // tokens then we have to adjust the deduct the quote tokens the user paid above from the remaining swap
            // quantity
            burnSwap = inBaseQty ? 0 : burnDown;
        }
    }

    /* @notice After calculating a burn down amount of collateral, roll the curve over
     *         into the next tick above the current tick. */
    function setShaveUp(CurveMath.CurveState memory curve, bool inBaseQty, uint128 burnDown)
        private
        pure
        returns (int128 paidBase, int128 paidQuote, uint128 burnSwap)
    {
        unchecked {
            if (curve.priceRoot_ < TickMath.MAX_SQRT_RATIO - 1) {
                curve.priceRoot_ += 1; // MAX_SQRT is well below uint128.max
            }
            // When moving the price up at constant liquidity, no additional quote tokens are required for
            // collateralization
            paidQuote = 0;

            // When moving the price up at constant liquidity, the swapper must pay a small amount of additional
            // base tokens to keep the curve over-collateralized.
            paidBase = burnDown.toInt128Sign();

            // If the fixed swap leg is in quote tokens, then this has zero impact, if the swap leg is in base
            // tokens then we have to adjust the deduct the quote tokens the user paid above from the remaining swap
            // quantity
            burnSwap = inBaseQty ? burnDown : 0;
        }
    }

    /* @notice After previously calculating the denominated and counter-denominated flows,
     *         this function assigns those to the correct side of the pair and decrements
     *         the total swap quantity by the amount spent. */
    function setCurvePos(
        CurveMath.CurveState memory curve,
        bool inBaseQty,
        bool isBuy,
        uint128 swapQty,
        uint128 price,
        int128 paidFlow,
        int128 paidCounter
    ) private pure returns (int128 paidBase, int128 paidQuote, uint128 qtyLeft) {
        uint128 spent = flowToSpent(paidFlow, inBaseQty, isBuy);

        if (spent >= swapQty) {
            qtyLeft = 0;
        } else {
            qtyLeft = swapQty - spent;
        }

        paidBase = (inBaseQty ? paidFlow : paidCounter);
        paidQuote = (inBaseQty ? paidCounter : paidFlow);
        curve.priceRoot_ = price;
    }

    /* @notice Convert a signed paid flow to a decrement to apply to swap qty left. */
    function flowToSpent(int128 paidFlow, bool inBaseQty, bool isBuy) private pure returns (uint128) {
        int128 spent = (inBaseQty == isBuy) ? paidFlow : -paidFlow;
        if (spent < 0) return 0;
        return uint128(spent);
    }

    /* @notice Calculates the flow and counterflow associated with moving the constant
     *         product curve to a target price.
     * @dev    Both sides of the flow are rounded down at up to 2 wei of precision loss
     *         (see CurveMath.sol). The results should not be used directly without 
     *         buffering the counterflow in the direction of collateral support. */
    function deriveDemand(CurveMath.CurveState memory curve, uint128 price, bool inBaseQty)
        private
        pure
        returns (uint128 flow, uint128 counterFlow)
    {
        uint128 liq = curve.activeLiquidity();
        uint128 baseFlow = liq.deltaBase(curve.priceRoot_, price);
        uint128 quoteFlow = liq.deltaQuote(curve.priceRoot_, price);
        if (inBaseQty) {
            (flow, counterFlow) = (baseFlow, quoteFlow);
        } else {
            (flow, counterFlow) = (quoteFlow, baseFlow);
        }
    }

    /* @notice Given a fixed swap flow on a cosntant product AMM curve, calculates
     *   the final price and counterflow. This function assumes that the AMM curve is
     *   constant product stable through the impact range. It's the caller's 
     *   responsibility to check that we're not passing liquidity bump tick boundaries.
     *
     * @dev The price and counter-flow guarantee collateral stability on the AMM curve.
     *   Because of fixed-point effects the price may be arbitarily rounded, but the 
     *   counter-flow will always be set correctly to match. The result of this function
     *   is based on the AMM curve being constant through the entire range. Note that 
     *   this function only calulcates a result it does *not* write into the Curve or 
     *   Swap structs.
     *
     * @param curve The constant-product AMM curve
     * @param flow  The fixed token flow from the side the swap is denominated in.
     * @param inBaseQty If true, the flow is denominated in base-side tokens.
     * @param isBuy If true, the flows are paying base tokens to the pool and receiving
     *              quote tokens.
     *
     * @return counterFlow The magnitude of token flow on the opposite side the swap
     *                     is denominated in. Note that this value is *not* signed. Also
     *                     note that this value is always rounded down. 
     * @return nextPrice   The ending price of the curve assuming the full flow is 
     *                     processed. Note that this value is *not* written into the 
     *                     curve struct. */
    function deriveImpact(CurveMath.CurveState memory curve, uint128 flow, bool inBaseQty, bool isBuy)
        internal
        pure
        returns (uint128 counterFlow, uint128 nextPrice)
    {
        uint128 liq = curve.activeLiquidity();
        nextPrice = deriveFlowPrice(curve.priceRoot_, liq, flow, inBaseQty, isBuy);

        /* We calculate the counterflow exactly off the computed price. Ultimately safe
         * collateralization only cares about the price, not the contravening flow.
         * Therefore we always compute based on the final, rounded price, not from the
         * original fixed flow. */
        counterFlow =
            !inBaseQty ? liq.deltaBase(curve.priceRoot_, nextPrice) : liq.deltaQuote(curve.priceRoot_, nextPrice);
    }

    /* @dev The end price is always rounded to the inside of the flow token:
     *
     *       Flow   |   Dir   |  Price Roudning  | Loss of Precision
     *     ---------------------------------------------------------------
     *       Base   |   Buy   |     Down         |    1 wei
     *       Base   |   Sell  |     Down         |    1 wei
     *       Quote  |   Buy   |     Up           |   Arbitrary
     *       Quote  |   Sell  |     Up           |   Arbitrary
     * 
     *   This guarantees that the pool is adaquately collateralized given the flow of the
     *   fixed side. Because of the arbitrary roudning, it's critical that the counter-
     *   flow is computed using the exact price returned by this function, and not 
     *   independently. */
    function deriveFlowPrice(uint128 price, uint128 liq, uint128 flow, bool inBaseQty, bool isBuy)
        private
        pure
        returns (uint128)
    {
        uint128 curvePrice =
            inBaseQty ? calcBaseFlowPrice(price, liq, flow, isBuy) : calcQuoteFlowPrice(price, liq, flow, isBuy);

        if (curvePrice >= TickMath.MAX_SQRT_RATIO) return TickMath.MAX_SQRT_RATIO - 1;
        if (curvePrice < TickMath.MIN_SQRT_RATIO) return TickMath.MIN_SQRT_RATIO;
        return curvePrice;
    }

    /* Because the base flow is fixed, we want to always set the price in favor of 
     * base token over-collateralization. Upstream, we'll independently set quote token
     * flows based off the price calculated here. Since higher price increases base 
     * collateral, we round price down regardless of whether the fixed base flow is a 
     * buy or a sell. 
     *
     * This seems counterintuitive when base token is the output, but even then moving 
     * the price further down will increase the quote token input and over-collateralize
     * the base token. The max loss of precision is 1 unit of fixed-point price. */
    function calcBaseFlowPrice(uint128 price, uint128 liq, uint128 flow, bool isBuy) private pure returns (uint128) {
        if (liq == 0) return type(uint128).max;

        uint192 deltaCalc = FixedPoint.divQ64(flow, liq);
        if (deltaCalc > type(uint128).max) return type(uint128).max;
        uint128 priceDelta = uint128(deltaCalc);

        /* For a fixed amount of base flow tokens, the resulting price should be conservatively
         * rounded down. Since Price = [Base Reserves]/[Quote Reserves], rounding price down
         * is equivalent to rounding the curve to be over collateralized relative to the actual
         * physical base tokens. */
        if (isBuy) {
            // Since priceDelta is rounded down to the lower unit, this equation rounds down the
            // the price by up to 1 unit
            return price + priceDelta;
        } else {
            if (priceDelta >= price) return 0;
            // priceDelta is rounded down by a maximum of 1 unit, so adding 1 to the subtracted
            // priceDelta value rounds price down by up to 1 unit.
            return price - (priceDelta + 1);
        }
    }

    /* The same rounding logic as calcBaseFlowPrice applies, but because it's the 
     * opposite side we want to conservatively round the price *up*, regardless of 
     * whether it's a buy or sell. 
     * 
     * Calculating flow price for quote flow is more complex because the flow delta 
     * applies to the inverse of the price. So when calculating the inverse, we make 
     * sure to round in the direction that rounds up the final price. */
    function calcQuoteFlowPrice(uint128 price, uint128 liq, uint128 flow, bool isBuy) private pure returns (uint128) {
        // Since this is a term in the quotient rounding down, rounds up the final price
        uint128 invPrice = FixedPoint.recipQ64(price);
        // This is also a quotient term so we use this function's round down logic
        uint128 invNext = calcBaseFlowPrice(invPrice, liq, flow, !isBuy);
        if (invNext == 0) return TickMath.MAX_SQRT_RATIO;
        return FixedPoint.recipQ64(invNext) + 1;
    }

    // Max round precision loss on token flow is 2 wei, but a 4 wei cushion provides
    // extra margin and is economically meaningless.
    int128 constant ROUND_PRECISION_WEI = 4;

    /* @notice Correctly assigns the signed direction to the unsigned flow and counter
     *   flow magnitudes that were previously computed for a fixed flow swap. Positive 
     *   sign implies the flow is being received by the pool, negative that it's being 
     *   received by the user. */
    function signFlow(uint128 flowMagn, uint128 counterMagn, bool inBaseQty, bool isBuy)
        private
        pure
        returns (int128 flow, int128 counter)
    {
        (flow, counter) = signMagn(flowMagn, counterMagn, inBaseQty, isBuy);
        // Conservatively round directional counterflow in the direction of the pool's
        // collateral. Don't round swap flow because that's a fixed target.
        counter = counter + ROUND_PRECISION_WEI;
    }

    /* @notice Same as signFlow, but used for the flow from a price target swap leg. */
    function signFixed(uint128 flowMagn, uint128 counterMagn, bool inBaseQty, bool isBuy)
        private
        pure
        returns (int128 flow, int128 counter)
    {
        (flow, counter) = signMagn(flowMagn, counterMagn, inBaseQty, isBuy);
        // In a price target, bothsides of the flow are floating, and have to be rounded
        // in pool's favor to conservatively accomodate the price precision.
        flow = flow + ROUND_PRECISION_WEI;
        counter = counter + ROUND_PRECISION_WEI;
    }

    /* @notice Takes an unsigned flow magntiude and correctly signs it based on the
     *         directional and denomination of the flows. */
    function signMagn(uint128 flowMagn, uint128 counterMagn, bool inBaseQty, bool isBuy)
        private
        pure
        returns (int128 flow, int128 counter)
    {
        if (inBaseQty == isBuy) {
            (flow, counter) = (flowMagn.toInt128Sign(), -counterMagn.toInt128Sign());
        } else {
            (flow, counter) = (-flowMagn.toInt128Sign(), counterMagn.toInt128Sign());
        }
    }
}

/* @title Swap Curve library.
 * @notice Library contains functionality for fully applying a swap directive to 
 *         a locally stable AMM liquidty curve within the bounds of the stable range,
 *         in a way that accumulates fees onto the curve's liquidity. */
library SwapCurve {
    using SafeCast for uint128;
    using CurveMath for CurveMath.CurveState;
    using CurveAssimilate for CurveMath.CurveState;
    using CurveRoll for CurveMath.CurveState;
    using Chaining for Chaining.PairFlow;

    /* @notice Applies the swap on to the liquidity curve, either fully exhausting
     *   the swap or reaching the concentrated liquidity bounds or the user-specified
     *   limit price. After calling, the curve and swap objects will be updated with
     *   the swap price impact, the liquidity fees assimilated into the curve's ambient
     *   liquidity, and the swap accumulators incremented with the cumulative flows.
     * 
     * @param curve - The current in-range liquidity curve. After calling, price and
     *    fee accumulation will be adjusted based on the swap processed in this leg.
     * @param accum - An accumulator for the asset pair the swap/curve applies to.
     *    This object will be incremented with the flow processed on this leg. The swap
     *    may or may not be fully exhausted. Caller should check the swap.qty_ field.
     @ @param swap - The user directive specifying the swap to execute on this curve.
     *    Defines the direction, size, and limit price. After calling, the swapQty will
     *    be decremented with the amount of size executed in this leg.
     * @param pool - The specifications for the pool's AMM curve, notably in this context
     *    the fee rate and protocol take.     *
     * @param bumpTick - The tick boundary, past which the constant product AMM 
     *    liquidity curve is no longer known to be valid. (Either because it represents
     *    a liquidity bump point, or the end of a tick bitmap horizon.) The curve will 
     *    never move past this tick boundary in the call. Caller's responsibility is to 
     *    set this parameter in the correct direction. I.e. buys should be the boundary 
     *    from above and sells from below. Represented as a price tick index. */
    function swapToLimit(
        CurveMath.CurveState memory curve,
        Chaining.PairFlow memory accum,
        Directives.SwapDirective memory swap,
        PoolSpecs.Pool memory pool,
        int24 bumpTick
    ) internal pure {
        uint128 limitPrice = determineLimit(bumpTick, swap.limitPrice_, swap.isBuy_);

        (int128 paidBase, int128 paidQuote, uint128 paidProto) =
            bookExchFees(curve, swap.qty_, pool, swap.inBaseQty_, limitPrice);
        accum.accumSwap(swap.inBaseQty_, paidBase, paidQuote, paidProto);

        // limitPrice is still valid even though curve has moved from ingesting liquidity
        // fees in bookExchFees(). That's because the collected fees are mathematically
        // capped at a fraction of the flow necessary to reach limitPrice. See
        // bookExchFees() comments. (This is also why we book fees before swapping, so we
        // don't run into the limitPrice when trying to ingest fees.)
        (paidBase, paidQuote, swap.qty_) = swapOverCurve(curve, swap.inBaseQty_, swap.isBuy_, swap.qty_, limitPrice);
        accum.accumSwap(swap.inBaseQty_, paidBase, paidQuote, 0);
    }

    /* @notice Calculates the exchange fee given a swap directive and limitPrice. Note 
     *   this assumes the curve is constant-product without liquidity bumps through the
     *   whole range. Don't use this function if you're unable to guarantee that the AMM
     *   curve is locally stable through the price impact.
     *
     * @param curve The current state of the AMM liquidity curve. Must be stable without
     *              liquidity bumps through the price impact.
     * @param swapQty The quantity specified for this leg of the swap, may or may not be
     *                fully executed depending on limitPrice.
     * @param feeRate The pool's fee as a proportion of notion executed. Represented as
     *                a multiple of 0.0001%
     * @param protoTake The protocol's take as a share of the exchange fee. (Rest goes to
     *                  liquidity rewards.) Represented as 1/n (with zero a special case.)
     * @param inBaseQty If true the swap quantity is denominated as base-side tokens. If 
     *                  false, quote-side tokens.
     * @param limitPrice The max (min) price this leg will swap to if it's a buy (sell).
     *                   Represented as the square root of price as a Q64.64 fixed-point.
     *
     * @return liqFee The total fees that's allocated as liquidity rewards accumulated
     *                to liquidity providers in the pool (in the opposite side tokens of
     *                the swap denomination).
     * @return protoFee The total fee accumulated as CrocSwap protocol fees. */
    function calcFeeOverSwap(
        CurveMath.CurveState memory curve,
        uint128 swapQty,
        uint16 feeRate,
        uint8 protoTake,
        bool inBaseQty,
        uint128 limitPrice
    ) internal pure returns (uint128 liqFee, uint128 protoFee) {
        uint128 flow = curve.calcLimitCounter(swapQty, inBaseQty, limitPrice);
        (liqFee, protoFee) = calcFeeOverFlow(flow, feeRate, protoTake);
    }

    /* @notice Give a pre-determined price limit, executes a fixed amount of swap 
     *         quantity into the liquidity curve. 
     *
     * @dev    Note that this function does *not* process liquidity fees, and those should
     *         be collected and assimilated into the curve *before* calling this function.
     *         Otherwise we may reach the end of the locally stable curve and not be able
     *         to correctly account for the impact on the curve.
     *
     * @param curve The liquidity curve state being executed on. This object will update 
     *              with the post-swap impact.
     * @param inBaseQty If true, the swapQty param is denominated in base-side tokens.
     * @param isBuy If true, the swap is paying base tokens to the pool and receiving 
     *              quote tokens.
     * @param swapQty The total quantity to be swapped. May or may not be fully exhausted
     *                depending on limitPrice.
     * @param limitPrice The max (min) price this leg will swap to if it's a buy (sell).
     *                   Represented as the square root of price as a Q64.64 fixed-point.
     *
     * @return paidBase The amount of base-side token flow associated with this leg of
     *                  the swap (not counting previously collected fees). If negative
     *                  pool is paying out base-tokens. If positive pool is collecting.
     * @return paidQuote The amount of quote-side token flow for this leg of the swap.
     * @return qtyLeft The total amount of swapQty left after this leg executes. If swap
     *                 fully executes, this value will be zero. */
    function swapOverCurve(
        CurveMath.CurveState memory curve,
        bool inBaseQty,
        bool isBuy,
        uint128 swapQty,
        uint128 limitPrice
    ) private pure returns (int128 paidBase, int128 paidQuote, uint128 qtyLeft) {
        uint128 realFlows = curve.calcLimitFlows(swapQty, inBaseQty, limitPrice);
        bool hitsLimit = realFlows < swapQty;

        if (hitsLimit) {
            (paidBase, paidQuote, qtyLeft) = curve.rollPrice(limitPrice, inBaseQty, isBuy, swapQty);
            assertPriceEndStable(curve, qtyLeft, limitPrice);
        } else {
            (paidBase, paidQuote, qtyLeft) = curve.rollFlow(realFlows, inBaseQty, isBuy, swapQty);
            assertFlowEndStable(curve, qtyLeft, isBuy, limitPrice);
        }
    }

    /* In rare corner cases, swap can result in a corrupt end state. This occurs
     * when the swap flow lands within in a rounding error of the limit price. That 
     * potentially creates an error where we're swapping through a curve price range
     * without supported liquidity. 
     *
     * The other corner case is the flow based swap not exhausting liquidity for some
     * code or rounding reason. The upstream logic uses the exhaustion of the swap qty
     * to determine whether a liquidity bump was reached. In this case it would try to
     * inappropriately kick in liquidity at a bump the price hasn't reached.
     *
     * In both cases the condition is so astronomically rare that we just crash the 
     * transaction. */
    function assertFlowEndStable(CurveMath.CurveState memory curve, uint128 qtyLeft, bool isBuy, uint128 limitPrice)
        private
        pure
    {
        bool insideLimit = isBuy ? curve.priceRoot_ < limitPrice : curve.priceRoot_ > limitPrice;
        bool hasNone = qtyLeft == 0;
        require(insideLimit && hasNone, "RF");
    }

    /* Similar to asserFlowEndStable() but for limit-bound swap legs. Due to rounding 
     * effects we may also simultaneously exhaust the flow at the same exact point we
     * reach the limit barrier. This could corrupt the upstream logic which uses the
     * remaining qty to determine whether we've reached a tick bump. 
     * 
     * In this case the corner case would mean it would fail to kick in new liquidity 
     * that's required by reaching the tick bump limit. Again this is so astronomically 
     * rare for non-pathological curves that we just crash the transaction. */
    function assertPriceEndStable(CurveMath.CurveState memory curve, uint128 qtyLeft, uint128 limitPrice)
        private
        pure
    {
        bool atLimit = curve.priceRoot_ == limitPrice;
        bool hasRemaining = qtyLeft > 0;
        require(atLimit && hasRemaining, "RP");
    }

    /* @notice Determines an effective limit price given the combination of swap-
     *    specified limit, tick liquidity bump boundary on the locally stable AMM curve,
     *    and the numerical boundaries of the price field. Always picks the value that's
     *    most to the inside of the swap direction. */
    function determineLimit(int24 bumpTick, uint128 limitPrice, bool isBuy) private pure returns (uint128) {
        unchecked {
            uint128 bounded = boundLimit(bumpTick, limitPrice, isBuy);
            if (bounded < TickMath.MIN_SQRT_RATIO) return TickMath.MIN_SQRT_RATIO;
            if (bounded >= TickMath.MAX_SQRT_RATIO) return TickMath.MAX_SQRT_RATIO - 1; // Well above 0, cannot underflow
            return bounded;
        }
    }

    /* @notice Finds the effective max (min) swap limit price giving a bump tick index
     *         boundary and a user specified limitPrice.
     * 
     * @dev Because the mapping from ticks to bumps always occur at the lowest price unit
     *      inside a tick, there is an asymmetry between the lower and upper bump tick arg. 
     *      The lower bump tick is the lowest tick *inclusive* for which liquidity is active.
     *      The upper bump tick is the *next* tick above where liquidity is active. Therefore
     *      the lower liquidity price maps to the bump tick price, whereas the upper liquidity
     *      price bound maps to one unit less than the bump tick price.
     *
     *     Lower bump price                             Upper bump price
     *            |                                           |
     *      ------X******************************************+X-----------------
     *            |                                          |
     *     Min liquidity prce                         Max liquidity price
     */
    function boundLimit(int24 bumpTick, uint128 limitPrice, bool isBuy) private pure returns (uint128) {
        unchecked {
            if (bumpTick <= TickMath.MIN_TICK || bumpTick >= TickMath.MAX_TICK) {
                return limitPrice;
            } else if (isBuy) {
                /* See comment above. Upper bound liquidity is last active at the price one unit
             * below the upper tick price. */
                uint128 TICK_STEP_SHAVE_DOWN = 1;

                // Valid uint128 root prices are always well above 0.
                uint128 bumpPrice = TickMath.getSqrtRatioAtTick(bumpTick) - TICK_STEP_SHAVE_DOWN;
                return bumpPrice < limitPrice ? bumpPrice : limitPrice;
            } else {
                uint128 bumpPrice = TickMath.getSqrtRatioAtTick(bumpTick);
                return bumpPrice > limitPrice ? bumpPrice : limitPrice;
            }
        }
    }

    /* @notice Calculates exchange fee charge based off an estimate of the predicted
     *         order flow on this leg of the swap.
     * 
     * @dev    Note that the process of collecting the exchange fee itself alters the
     *   structure of the curve, because those fees assimilate as liquidity into the 
     *   curve new liquidity. As such the flow used to pro-rate fees is only an estimate
     *   of the actual flow that winds up executed. This means that fees are not exact 
     *   relative to realized flows. But because fees only have a small impact on the 
     *   curve, they'll tend to be very close. Getting fee exactly correct doesn't 
     *   matter, and either over or undershooting is fine from a collateral stability 
     *   perspective. */
    function bookExchFees(
        CurveMath.CurveState memory curve,
        uint128 swapQty,
        PoolSpecs.Pool memory pool,
        bool inBaseQty,
        uint128 limitPrice
    ) private pure returns (int128, int128, uint128) {
        (uint128 liqFees, uint128 exchFees) =
            calcFeeOverSwap(curve, swapQty, pool.feeRate_, pool.protocolTake_, inBaseQty, limitPrice);

        /* We can guarantee that the price shift associated with the liquidity
         * assimilation is safe. The limit price boundary is by definition within the
         * tick price boundary of the locally stable AMM curve (see determineLimit()
         * function). The liquidity assimilation flow is mathematically capped within 
         * the limit price flow, because liquidity fees are a small fraction of swap
         * flows. */
        curve.assimilateLiq(liqFees, inBaseQty);

        return assignFees(liqFees, exchFees, inBaseQty);
    }

    /* @notice Correctly applies the liquidity and protocol fees to the correct side in
     *         in th pair, given how the swap is denominated. */
    function assignFees(uint128 liqFees, uint128 exchFees, bool inBaseQty)
        private
        pure
        returns (int128 paidBase, int128 paidQuote, uint128 paidProto)
    {
        unchecked {
            // Safe for unchecked because total fees are always previously calculated in
            // 128-bit space
            uint128 totalFees = liqFees + exchFees;

            if (inBaseQty) {
                paidQuote = totalFees.toInt128Sign();
            } else {
                paidBase = totalFees.toInt128Sign();
            }
            paidProto = exchFees;
        }
    }

    /* @notice Given a fixed flow and a fee rate, calculates the owed liquidty and 
     *         protocol fees. */
    function calcFeeOverFlow(uint128 flow, uint16 feeRate, uint8 protoProp)
        private
        pure
        returns (uint128 liqFee, uint128 protoFee)
    {
        unchecked {
            uint256 FEE_BP_MULT = 1_000_000;

            // Guaranteed to fit in 256 bit arithmetic. Safe to cast back to uint128
            // because fees will never be larger than the underlying flow.
            uint256 totalFee = (uint256(flow) * feeRate) / FEE_BP_MULT;
            protoFee = uint128(totalFee * protoProp / 256);
            liqFee = uint128(totalFee) - protoFee;
        }
    }
}

/* @title Curve caching library.
 * @notice Certain values related to the CurveState aren't stored (to save storage),
 *    but are relatively gas expensive to calculate. As such we want to cache these
 *    calculations in memory whenever possible to avoid duplicated effort. This library
 *    provides a convenient facility for that. */
library CurveCache {
    using TickMath for uint128;
    using CurveMath for CurveMath.CurveState;

    /* @notice Represents the underlying CurveState along with the tick price memory
     *         cache, and associated bookeeping.
     * 
     * @param curve_ The underlying CurveState object.
     * @params isTickClean_ If true, then the current price tick value is valid to use.
     * @params unsafePriceTick_ The price tick value (if previously cached). User should
     *              not access directly, but use the pullPriceTick() helper function. */
    struct Cache {
        CurveMath.CurveState curve_;
        bool isTickClean_;
        int24 unsafePriceTick_;
    }

    /* @notice Given a curve cache instance retrieves the price tick, if cached, or 
     *         calculates and cached if cache is dirty. */
    function pullPriceTick(Cache memory cache) internal pure returns (int24) {
        if (!cache.isTickClean_) {
            cache.unsafePriceTick_ = cache.curve_.priceRoot_.getTickAtSqrtRatio();
            cache.isTickClean_ = true;
        }
        return cache.unsafePriceTick_;
    }

    /* @notice Call on a curve cache object, when the underlying price has changed, and
     *         therefore the cache should be conisdered dirty. */
    function dirtyPrice(Cache memory cache) internal pure {
        cache.isTickClean_ = false;
    }
}

/* @notice Defines structures and functions necessary to track knockout liquidity. 
 *         Knockout liquidity works like standard concentrated range liquidity, *except*
 *         the position becomes inactive once the price of the curve breaches a certain
 *         tick pivot. In that sense knockout liquidity behaves like a "non-reversible
 *         limit order" seen in the traditional limit order book. */
library KnockoutLiq {
    /* @notice Defines a currently active knockout liquidity bump point that exists on
     *         a specific AMM curve at a specific tick/direction.
     *
     * @param lots_ The total number of lots active in the knockout pivot. Note that this
     *              number should always be included in the corresponding LevelBook lots.
     *
     * @param pivotTime_ The block time the first liquidity was created on the pivot 
     *                   point. This resets every time the knockout is crossed, and is
     *                   therefore used to distinguish tranches of liquidity that were
     *                   added at the same tick but with different knockout times.
     *
     * @param rangeTicks_ The number of ticks wide the range order for the knockout 
     *                    tranche. Unlike traditional concentrated liquidity, all knockout
     *                    liquidity in the same tranche must have the same width. This is
     *                    used to determine what counter-side tick to decrement liquidity
     *                    on when knocking out an order. */
    struct KnockoutPivot {
        uint96 lots_;
        uint32 pivotTime_;
        uint16 rangeTicks_;
    }

    /* @notice Stores a cryptographically provable history of previous knockout events
     *         at a given tick/direction. 
     *
     * @dev To avoid unnecessary SSTORES, we Merkle at the same location instead of 
     *      growing an array. This allows users trying to claim a previously knockout 
     *      position to post a Merkle proof. (And since the underlying liquidity is 
     *      computable even without this proof, the only loss for those that don't are the
     *      accumulated fees while the range liquidity was active.)
     *
     * @param merkleRoot_ The Merkle root of the prior entry in the chain.
     * @param pivotTime_ The pivot time of the last tranche to be knocked out at this tick
     * @param feeMileage_ The fee mileage for the range at the time the tranche was 
     *                    knocked out. */
    struct KnockoutMerkle {
        uint160 merkleRoot_;
        uint32 pivotTime_;
        uint64 feeMileage_;
    }

    /* @notice Represents a single user's knockout liquidity position.
     * @param lots_ The total number of liquidity lots in the position. 
     * @param feeMileage_ The in-range cumulative fee mileage at the time the position was
     *                    created.
     * @param timestamp_ The block time the position was created (or when liquidity was
     *                   added to the position). */
    struct KnockoutPos {
        uint96 lots_;
        uint64 feeMileage_;
        uint32 timestamp_;
    }

    /* @notice Represents the location of a knockout position inside a given AMM curve.
     *         Necessary to recover a user's position in the storage.
     *
     * @param isBid_ If true, indicates that the knockout is on the bid side, i.e. will
     *                knockout when price falls below the tick.
     * @param lowerTick The 24-bit tick index of the lower boundary of the knockout range order
     * @param upperTick The 24-bit tick index of the upper boundary of the knockout range order */
    struct KnockoutPosLoc {
        bool isBid_;
        int24 lowerTick_;
        int24 upperTick_;
    }

    /* @notice Resets all fields on a existing pivot struct. */
    function deletePivot(KnockoutPivot storage pivot) internal {
        pivot.lots_ = 0;
        pivot.pivotTime_ = 0;
        pivot.rangeTicks_ = 0;
    }

    /* @notice Encodes a hash key for a given knockout pivot point.
     * @param pool The hash index of the AMM pool.
     * @param isBid If true indicates the knockout pivot is on the bid side.
     * @param tick The tick index of the knockout pivot.
     * @return Unique hash key mapping to the pivot struct. */
    function encodePivotKey(bytes32 pool, bool isBid, int24 tick) internal pure returns (bytes32) {
        return keccak256(abi.encode(pool, isBid, tick));
    }

    /* @notice Encodes a hash key for a knockout pivot given a pos location struct. */
    function encodePivotKey(KnockoutPosLoc memory loc, bytes32 pool) internal pure returns (bytes32) {
        return encodePivotKey(pool, loc.isBid_, knockoutTick(loc));
    }

    /* @notice Determines which tick side is the pivot point based on whether the pivot
     *         is a bid or ask. */
    function knockoutTick(KnockoutPosLoc memory loc) internal pure returns (int24) {
        return loc.isBid_ ? loc.lowerTick_ : loc.upperTick_;
    }

    function tickRange(KnockoutPosLoc memory loc) internal pure returns (uint16) {
        uint24 range = uint24(loc.upperTick_ - loc.lowerTick_);
        require(range < type(uint16).max);
        return uint16(range);
    }

    /* @notice Encodes a hash key for a knockout position. 
     * @param loc The location of the knockout position
     * @param pool The hash index of the AMM pool.
     * @param owner The claimant of the liquidity position.
     * @param pivotTime The timestamp of when the pivot tranche was created
     * @return Unique hash key to position. */
    function encodePosKey(KnockoutPosLoc memory loc, bytes32 pool, address owner, uint32 pivotTime)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(pool, owner, loc.isBid_, loc.lowerTick_, loc.upperTick_, pivotTime));
    }
    /* @notice Commits a now-crossed Knockout pivot to the merkle history for that tick
     *         location.
     * @param merkle The Merkle history object. Will be overwrriten by this function.
     * @param pivot The most recent pivot state. Should not call this unless the pivot has
     *              just been knocked out.
     * @param feeMileage The in-range fee mileage at the time of knockout crossing. */

    function commitKnockout(KnockoutMerkle storage merkle, KnockoutPivot memory pivot, uint64 feeMileage) internal {
        merkle.merkleRoot_ = rootLink(merkle, commitEntropySalt());
        merkle.pivotTime_ = pivot.pivotTime_;
        merkle.feeMileage_ = feeMileage;
    }

    /* @notice Returns hard-to-fake entropy at commit time to prevent a long-range 
     *         birthday collission attack.
     *
     * @dev Knockout commits use 160-bit hashes for the Merkle chain. A birthday 
     *      collission attack could be carried with 2^80 SHA256 hashes for an approximate
     *      cost of 10 billion dollars or 1 year of bitcoin mining. (See EIP-3607 for more
     *      discussion.) This mitigates the risk of a long run attack by injecting 160 
     *      bits of entropy from the block hash which can only be fully known at the time
     *      a Merkle root is committed. 
     *
     *      Even if an attacker is the block builder and can manipulate blockhash, they 
     *      can only control as many bits of blockhash entropy as SHA256 hashes they can 
     *      calculate in O(block time). Practically speaking an attacker will not be able
     *      to calculate more than 2^100 hashes at the scale of block times. 
     *      Therefore this salt injects a minimum of 60 bits of uncontrollable entropy, 
     *      and raises the cost of a long-range collision attack to 2^140 hashes, which 
     *      is outright infeasible. */
    function commitEntropySalt() internal view returns (uint160) {
        return uint160(uint256(blockhash(block.number - 1)));
    }

    /* @notice Converts the most recent Merkle state to a 160-bit Merkle root hash. */
    function rootLink(KnockoutMerkle memory merkle, uint160 salt) private pure returns (uint160) {
        return rootLink(merkle.merkleRoot_, merkle.pivotTime_, merkle.feeMileage_, salt);
    }

    /* @notice Converts the most current Merkle state params to 160-bit Merkle hash.*/
    function rootLink(uint160 root, uint32 pivotTime, uint64 feeMileage, uint160 salt) private pure returns (uint160) {
        return rootLink(root, encodeChainLink(pivotTime, feeMileage, salt));
    }

    /* @notice Hashes together the previous Merkle root with the encoded chain step. */
    function rootLink(uint160 root, uint256 chainLink) private pure returns (uint160) {
        bytes32 hash = keccak256(abi.encode(root, chainLink));
        return uint160(uint256(hash) >> 96);
    }

    /* @notice Tightly packs the 32-bit pivot time with the 64-bit fee mileage and the salt. */
    function encodeChainLink(uint32 pivotTime, uint64 feeMileage, uint160 salt) private pure returns (uint256) {
        return (uint256(salt) << 96) + (uint256(pivotTime) << 64) + uint256(feeMileage);
    }

    /* @notice Decodes a tightly packed chain link into the pivot time and fee mileage */
    function decodeChainLink(uint256 entry) private pure returns (uint32 pivotTime, uint64 feeMileage) {
        pivotTime = uint32((entry << 160) >> 224);
        feeMileage = uint64((entry << 192) >> 192);
    }

    /* @notice Verifies a Merkle proof for a previous knockout commitment.
     *
     * @param merkle The current Merkle chain for the pivot tick.
     * @param proofRoot The Merkle root the proof is starting at.
     * @param proof A proof that starts at the point in history the user wants to prove
     *              and includes the encoded 96-bit chain entries (see encodeChainLink())
     *              up to the current Merkle state.
     *
     * @return The 32-bit Knockout tranche pivot time and 64-bit fee mileage at the start of
     *         the proof. */
    function proveHistory(KnockoutMerkle memory merkle, uint160 proofRoot, uint256[] memory proof)
        internal
        pure
        returns (uint32, uint64)
    {
        // If we're only looking at the most recent knockout, it's still stored raw
        // and doesn't need a proof.
        return proof.length == 0 ? (merkle.pivotTime_, merkle.feeMileage_) : proveSteps(merkle, proofRoot, proof);
    }

    /* @notice Verifies a non-empty Merkle proof. */
    function proveSteps(KnockoutMerkle memory merkle, uint160 proofRoot, uint256[] memory proof)
        private
        pure
        returns (uint32, uint64)
    {
        uint160 incrRoot = proofRoot;
        unchecked {
            // Iterate by 1 loop will run out of gas far before overflowing 256 bits
            for (uint256 i = 0; i < proof.length; ++i) {
                incrRoot = rootLink(incrRoot, proof[i]);
            }
        }

        require(incrRoot == merkle.merkleRoot_, "KP");
        return decodeChainLink(proof[0]);
    }

    /* @notice Verifies that a given knockout location is valid relative to the curve
     *         price and the pool's current knockout parameters. If not, the call will
     *         revert
     *
     * @param loc The location for the proposed knockout liquidity candidate.
     * @param priceTick The tick index of the curves current price.
     *
     * @param loc The tightly packed knockout parameters related to the pool. The fields
     *            are set in the following order from most to least significant bit:
     *         [8]             [7]            [6][5]          [4][3][2][1]
     *        Unusued      On-Grid Flag      PlaceType         OrderWidth
     *            
     *            The field types are as follows:
     *               OrderWidth - The width of new knockout pivots in ticks represented by
     *                            power of two. 
     *               PlaceType - Restricts where new knockout pivots can be placed 
     *                           relative to curve price. Uses the following codes:
     *                    0 - Disabled. No knockout pivots allowed.
     *                    1 - Knockout bids (asks) must be placed with upper (lower) tick
     *                        below (above) the current curve price.
     *                    2 - Knockout bids (asks) must be placed with lower (upper) tick
     *                        below (above) the current curve price.
     *
     *              On-Grid Flag - If set requires that any new knockout range order can only
     *                             be placed on a tick index that's a multiple of the width. 
     *                             Can be used to restrict density of knockout orders, beyond 
     *                             the normal pool tick size. */
    function assertValidPos(KnockoutPosLoc memory loc, int24 priceTick, uint8 knockoutBits) internal pure {
        (bool enabled, uint8 width, bool inside, bool onGrid) = unpackBits(knockoutBits);

        require(enabled && gridOkay(loc, width, onGrid) && spreadOkay(loc, priceTick, inside), "KV");
    }

    /* @notice Evaluates whether the placement and width of a knockout pivot candidate
     *         conforms to the grid parameters. */
    function gridOkay(KnockoutPosLoc memory loc, uint8 widthBits, bool mustBeOnGrid) private pure returns (bool) {
        uint24 width = uint24(loc.upperTick_ - loc.lowerTick_);
        bool rightWidth = width == uint24(1) << widthBits;

        int24 tick = loc.upperTick_;
        uint24 absTick = tick > 0 ? uint24(tick) : uint24(-tick);
        bool onGrid = (!mustBeOnGrid) || (absTick >> widthBits) << widthBits == absTick;

        return rightWidth && onGrid;
    }

    /* @notice Evaluates whether the placement of a knockout pivot candidates conforms
     *         to the parameters relative to the curve's current price tick. */
    function spreadOkay(KnockoutPosLoc memory loc, int24 priceTick, bool inside) internal pure returns (bool) {
        // Checks to see whether the range order is placed directionally correct relative
        // to the current tick price. If inside is true, then the range order can be placed
        // with the curve price inside the range.
        // Otherwise bids must have the entire range below the curve price, and asks must
        // have the entire range above the curve price.
        if (loc.isBid_) {
            int24 refTick = inside ? loc.lowerTick_ : loc.upperTick_;
            return refTick < priceTick;
        } else {
            int24 refTick = inside ? loc.upperTick_ : loc.lowerTick_;
            return refTick >= priceTick;
        }
    }

    /* @notice Decodes the tightly packed bits in pool knockout parameters.
     * @return enabled True if new knockout pivots are enabled at all.
     * @return widthBits The width of new knockout pivots in ticks to the power of two.
     * @return inside  True if knockout range order can be minted with the current curve
     *                 price inside the tick range. If false, knockout range orders can
     *                 only be minted with the full range is outside the current curve 
     *                 price.
     * @return onGrid True if new knockout range orders are restricted to ticks that
     *                are multiples of the width size. */
    function unpackBits(uint8 knockoutBits)
        private
        pure
        returns (bool enabled, uint8 widthBits, bool inside, bool onGrid)
    {
        widthBits = uint8(knockoutBits & 0x0F);
        uint8 flagBits = uint8(knockoutBits & 0x30) >> 4;

        enabled = flagBits > 0;
        inside = flagBits >= 2;

        onGrid = knockoutBits & 0x40 > 0;
    }
}

/* @title Storage layout base layer
 * 
 * @notice Only exists to enforce a single consistent storage layout. Not
 *    designed to be externally used. All storage in any CrocSwap contract
 *    is defined here. That allows easy use of delegatecall() to move code
 *    over the 24kb into proxy contracts.
 *
 * @dev Any contract or mixin with local defined storage variables *must*
 *    define those storage variables here and inherit this mixin. Failure
 *    to do this may lead to storage layout inconsistencies between proxy
 *    contracts. */
contract StorageLayout {
    // Re-entrant lock. Should always be reset to 0x0 after the end of every
    // top-level call. Any top-level call should fail on if this value is non-
    // zero.
    //
    // Inside a call this address is always set to the beneficial owner that
    // the call is being made on behalf of. Therefore any positions, tokens,
    // or liquidity can only be accessed if and only if they're owned by the
    // value lockHolder_ is currently set to.
    //
    // In the case of third party relayer or router calls, this value should
    // always be set to the *client* that the call is being made for, and never
    // the msg.sender caller that is acting on the client behalf's. (Of course
    // for security, third party calls made on a client's behalf must always
    // be authorized by the client either by pre-approval or signature.)
    address internal lockHolder_;

    // Indicates whether a given protocolCmd() call is operating in escalated
    // privileged mode. *Must* always be reset to false after every call.
    bool internal sudoMode_;

    bool internal msgValSpent_;

    // If set to false, then the embedded hot-path (swap()) is not enabled and
    // users must use the hot proxy for the hot-path. By default set to true.
    bool internal hotPathOpen_;

    bool internal inSafeMode_;

    // The protocol take rate for relayer tips. Represented in 1/256 fractions
    uint8 internal relayerTakeRate_;

    // Slots for sidecar proxy contracts
    address[65536] internal proxyPaths_;

    // Address of the current dex protocol authority. Can be transferred
    address internal authority_;

    /**
     *
     */
    // LevelBook
    /**
     *
     */
    struct BookLevel {
        uint96 bidLots_;
        uint96 askLots_;
        uint64 feeOdometer_;
    }

    mapping(bytes32 => BookLevel) internal levels_;
    /**
     *
     */

    /**
     *
     */
    // Knockout Counters
    /**
     *
     */
    mapping(bytes32 => KnockoutLiq.KnockoutPivot) internal knockoutPivots_;
    mapping(bytes32 => KnockoutLiq.KnockoutMerkle) internal knockoutMerkles_;
    mapping(bytes32 => KnockoutLiq.KnockoutPos) internal knockoutPos_;
    /**
     *
     */

    /**
     *
     */
    // TickCensus
    /**
     *
     */
    mapping(bytes32 => uint256) internal mezzanine_;
    mapping(bytes32 => uint256) internal terminus_;
    /**
     *
     */

    /**
     *
     */
    // PoolRegistry
    /**
     *
     */
    mapping(uint256 => PoolSpecs.Pool) internal templates_;
    mapping(bytes32 => PoolSpecs.Pool) internal pools_;
    mapping(address => PriceGrid.ImproveSettings) internal improves_;
    uint128 internal newPoolLiq_;
    uint8 internal protocolTakeRate_;
    /**
     *
     */

    /**
     *
     */
    // ProtocolAccount
    /**
     *
     */
    mapping(address => uint128) internal feesAccum_;
    /**
     *
     */

    /**
     *
     */
    // PositionRegistrar
    /**
     *
     */
    struct RangePosition {
        uint128 liquidity_;
        uint64 feeMileage_;
        uint32 timestamp_;
        bool atomicLiq_;
    }

    struct AmbientPosition {
        uint128 seeds_;
        uint32 timestamp_;
    }

    mapping(bytes32 => RangePosition) internal positions_;
    mapping(bytes32 => AmbientPosition) internal ambPositions_;
    /**
     *
     */

    /**
     *
     */
    // LiquidityCurve
    /**
     *
     */
    mapping(bytes32 => CurveMath.CurveState) internal curves_;
    /**
     *
     */

    /**
     *
     */
    // UserBalance settings
    /**
     *
     */
    struct UserBalance {
        // Multiple loosely related fields are grouped together to allow
        // off-chain users to optimize calls to minimize cold SLOADS by
        // hashing needed data to the same slots.
        uint128 surplusCollateral_;
        uint32 nonce_;
        uint32 agentCallsLeft_;
    }

    mapping(bytes32 => UserBalance) internal userBals_;
    /**
     *
     */

    address treasury_;
    uint64 treasuryStartTime_;
}

/* @notice Contains the storage or storage hash offsets of the fields and sidecars
 *         in StorageLayer.
 *
 * @dev Note that if the struct of StorageLayer changes, these slot locations *will*
 *      change, and the values below will have to be manually updated. */
library CrocSlots {
    // Slot location of storage slots and/or hash map storage slot offsets. Values below
    // can be used to directly read state in CrocSwapDex by other contracts.
    uint256 public constant AUTHORITY_SLOT = 0;
    uint256 public constant LVL_MAP_SLOT = 65538;
    uint256 public constant KO_PIVOT_SLOT = 65539;
    uint256 public constant KO_MERKLE_SLOT = 65540;
    uint256 public constant KO_POS_SLOT = 65541;
    uint256 public constant POOL_TEMPL_SLOT = 65544;
    uint256 public constant POOL_PARAM_SLOT = 65545;
    uint256 public constant FEE_MAP_SLOT = 65548;
    uint256 public constant POS_MAP_SLOT = 65549;
    uint256 public constant AMB_MAP_SLOT = 65550;
    uint256 public constant CURVE_MAP_SLOT = 65551;
    uint256 public constant BAL_MAP_SLOT = 65552;

    // The slots of the currently attached sidecar proxy contracts. These are set by
    // covention and should be expanded over time as more sidecars are installed. For
    // backwards compatibility, upgraders should never break existing interface on
    // a pre-existing proxy sidecar.
    uint16 constant BOOT_PROXY_IDX = 0;
    uint16 constant SWAP_PROXY_IDX = 1;
    uint16 constant LP_PROXY_IDX = 2;
    uint16 constant COLD_PROXY_IDX = 3;
    uint16 constant LONG_PROXY_IDX = 4;
    uint16 constant MICRO_PROXY_IDX = 5;
    uint16 constant MULTICALL_PROXY_IDX = 6;
    uint16 constant KNOCKOUT_LP_PROXY_IDX = 7;
    uint16 constant FLAG_CROSS_PROXY_IDX = 3500;
    uint16 constant SAFE_MODE_PROXY_PATH = 9999;
}

// Not used in production. Just used so we can easily check struct size in hardhat.
contract StoragePrototypes is StorageLayout {
    UserBalance bal_;
    CurveMath.CurveState curve_;
    RangePosition pos_;
    AmbientPosition amb_;
    BookLevel lvl_;
}

/* @notice Standard interface for a permit oracle to be used by a permissioned pool. 
 * 
 * @dev For pools under their control permit oracles have the ability to approve or deny
 *      pool initialization, swaps, mints and burns for all liquidity types (ambient,
 *      concentrated and knockout). 
 * 
 *      Note that permit oracles do *not* have the ability to restrict claims or recovers 
 *      on post-knockout liquidity. An order is eligible to be claimed/recovered only after
 *      its liquidity has been knocked out of the curve, and is no longer active. Since a
 *      no longer active order does not affect the liquidity or state of the curve, permit
 *      oracles have no economic reason to restrict knockout claims/recovers. */
interface ICrocPermitOracle {
    /* @notice Verifies whether a given user is permissioned to perform an arbitrary 
     *          action on the pool.
     *
     * @param user The address of the caller to the contract.
     * @param sender The value of msg.sender for the caller of the action. Will either
     *               be same as user, the calling router, or the off-chain relayer.
     * @param base  The base-side token in the pair.
     * @param quote The quote-side token in the pair.
     * @param ambient The ambient liquidity directive for the pool action (possibly zero)
     * @param swap    The swap directive for the pool (possibly zero)
     * @param concs   The concentrated liquidity directives for the pool (possibly empty)
     * @param poolFee The effective pool fee set for the swap (either the base fee or the
     *                base fee plus user tip).
     *
     * @returns discount    Either returns 0, indicating the action is not approved at all.
     *                      Or returns the discount (in units of 0.0001%) that should be applied
     *                      to the pool's pre-existing swap fee on this call. Be aware that this value
     *                      is defined in terms of N-1 (because 0 is already used to indicate failure).
     *                      Hence return value of 1 indicates a discount of 0, return value of 2 
     *                      indicates discount of 0.0001%, return value of 3 is 0.0002%, and so on */
    function checkApprovedForCrocPool(
        address user,
        address sender,
        address base,
        address quote,
        Directives.AmbientDirective calldata ambient,
        Directives.SwapDirective calldata swap,
        Directives.ConcentratedDirective[] calldata concs,
        uint16 poolFee
    ) external returns (uint16 discount);

    /* @notice Verifies whether a given user is permissioned to perform a swap on the pool
     *
     * @param user The address of the caller to the contract.
     * @param sender The value of msg.sender for the caller of the action. Will either
     *               be same as user, the calling router, or the off-chain relayer.
     * @param base The base-side token in the pair.
     * @param quote The quote-side token in the pair.
     * @param isBuy  If true, the swapper is paying base and receiving quote
     * @param inBaseQty  If true, the qty is denominated in the base token side.
     * @param qty        The full qty on the swap request (could possibly be lower if user
     *                   hits limit price.
     * @param poolFee The effective pool fee set for the swap (either the base fee or the
     *                base fee plus user tip).

     * @returns discount    Either returns 0, indicating the action is not approved at all.
     *                      Or returns the discount (in units of 0.0001%) that should be applied
     *                      to the pool's pre-existing swap fee on this call. Be aware that this value
     *                      is defined in terms of N-1 (because 0 is already used to indicate failure).
     *                      Hence return value of 1 indicates a discount of 0, return value of 2 
     *                      indicates discount of 0.0001%, return value of 3 is 0.0002%, and so on */
    function checkApprovedForCrocSwap(
        address user,
        address sender,
        address base,
        address quote,
        bool isBuy,
        bool inBaseQty,
        uint128 qty,
        uint16 poolFee
    ) external returns (uint16 discount);

    /* @notice Verifies whether a given user is permissioned to mint liquidity
     *         on the pool.
     *
     * @param user The address of the caller to the contract.
     * @param sender The value of msg.sender for the caller of the action. Will either
     *               be same as user, the calling router, or the off-chain relayer.
     * @param base The base-side token in the pair.
     * @param quote The quote-side token in the pair.
     * @param bidTick  The tick index of the lower side of the range (0 if ambient)
     * @param askTick  The tick index of the upper side of the range (0 if ambient)
     * @param liq      The total amount of liquidity being minted. Denominated as 
     *                 sqrt(X*Y)
     *
     * @returns       Returns true if action is permitted. If false, CrocSwap will revert
     *                the transaction. */
    function checkApprovedForCrocMint(
        address user,
        address sender,
        address base,
        address quote,
        int24 bidTick,
        int24 askTick,
        uint128 liq
    ) external returns (bool);

    /* @notice Verifies whether a given user is permissioned to burn liquidity
     *         on the pool.
     *
     * @param user The address of the caller to the contract.
     * @param sender The value of msg.sender for the caller of the action. Will either
     *               be same as user, the calling router, or the off-chain relayer.
     * @param base The base-side token in the pair.
     * @param quote The quote-side token in the pair.
     * @param bidTick  The tick index of the lower side of the range (0 if ambient)
     * @param askTick  The tick index of the upper side of the range (0 if ambient)
     * @param liq      The total amount of liquidity being minted. Denominated as 
     *                 sqrt(X*Y)
     *
     * @returns       Returns true if action is permitted. If false, CrocSwap will revert
     *                the transaction. */
    function checkApprovedForCrocBurn(
        address user,
        address sender,
        address base,
        address quote,
        int24 bidTick,
        int24 askTick,
        uint128 liq
    ) external returns (bool);

    /* @notice Verifies whether a given user is permissioned to initialize a pool
     *         attached to this oracle.
     *
     * @param user The address of the caller to the contract.
     * @param sender The value of msg.sender for the caller of the action. Will either
     *               be same as user, the calling router, or the off-chain relayer.
     * @param base The base-side token in the pair.
     * @param quote The quote-side token in the pair.
     * @param poolIdx The Croc-specific pool type index the pool is being created on.
     *
     * @returns       Returns true if action is permitted. If false, CrocSwap will revert
     *                the transaction, and pool will not be initialized. */
    function checkApprovedForCrocInit(address user, address sender, address base, address quote, uint256 poolIdx)
        external
        returns (bool);

    /* @notice Just used to validate the contract address at pool creation time. */
    function acceptsPermitOracle() external returns (bool);
}

/* @title Pool registry mixin
 * @notice Provides a facility for registering and querying pool types on pairs and
 *         generalized pool templates for pools yet to be initialized. */
contract PoolRegistry is StorageLayout {
    using PoolSpecs for uint8;
    using PoolSpecs for PoolSpecs.Pool;

    uint8 constant SWAP_ACT_CODE = 1;
    uint8 constant MINT_ACT_CODE = 2;
    uint8 constant BURN_ACT_CODE = 3;
    uint8 constant COMP_ACT_CODE = 4;

    /* @notice Tests whether the given swap by the given user is authorized on this
     *         specific pool. If not, reverts the transaction. If pool is permissionless
     *         this function will just noop. */
    function verifyPermitSwap(
        PoolSpecs.PoolCursor memory pool,
        address base,
        address quote,
        bool isBuy,
        bool inBaseQty,
        uint128 qty
    ) internal {
        if (pool.oracle_ != address(0)) {
            uint16 discount = ICrocPermitOracle(pool.oracle_).checkApprovedForCrocSwap(
                lockHolder_, msg.sender, base, quote, isBuy, inBaseQty, qty, pool.head_.feeRate_
            );
            applyDiscount(pool, discount);
        }
    }

    /* @notice Tests whether the given mint by the given user is authorized on this
     *         specific pool. If not, reverts the transaction. If pool is permissionless
     *         this function will just noop. */
    function verifyPermitMint(
        PoolSpecs.PoolCursor memory pool,
        address base,
        address quote,
        int24 bidTick,
        int24 askTick,
        uint128 liq
    ) internal {
        if (pool.oracle_ != address(0)) {
            bool approved = ICrocPermitOracle(pool.oracle_).checkApprovedForCrocMint(
                lockHolder_, msg.sender, base, quote, bidTick, askTick, liq
            );
            require(approved, "Z");
        }
    }

    /* @notice Tests whether the given burn by the given user is authorized on this
     *         specific pool. If not, reverts the transaction. If pool is permissionless
     *         this function will just noop. */
    function verifyPermitBurn(
        PoolSpecs.PoolCursor memory pool,
        address base,
        address quote,
        int24 bidTick,
        int24 askTick,
        uint128 liq
    ) internal {
        if (pool.oracle_ != address(0)) {
            bool approved = ICrocPermitOracle(pool.oracle_).checkApprovedForCrocBurn(
                lockHolder_, msg.sender, base, quote, bidTick, askTick, liq
            );
            require(approved, "Z");
        }
    }

    /* @notice Tests whether the given pool directive by the given user is authorized on 
     *         this specific pool. If not, reverts the transaction. If pool is 
     *         permissionless this function will just noop. */
    function verifyPermit(
        PoolSpecs.PoolCursor memory pool,
        address base,
        address quote,
        Directives.AmbientDirective memory ambient,
        Directives.SwapDirective memory swap,
        Directives.ConcentratedDirective[] memory concs
    ) internal {
        if (pool.oracle_ != address(0)) {
            uint16 discount = ICrocPermitOracle(pool.oracle_).checkApprovedForCrocPool(
                lockHolder_, msg.sender, base, quote, ambient, swap, concs, pool.head_.feeRate_
            );
            applyDiscount(pool, discount);
        }
    }

    function applyDiscount(PoolSpecs.PoolCursor memory pool, uint16 discount) private pure {
        // Convention from permit oracle return value. Uses 0 for non-approved (meaning we
        // should rever), 1 for 0 discount, 2 for 0.0001% discount, and so on
        uint16 DISCOUNT_OFFSET = 1;
        require(discount > 0, "Z");
        pool.head_.feeRate_ -= (discount - DISCOUNT_OFFSET);
    }

    /* @notice Tests whether the given initialization by the given user is authorized on this
     *         specific pool. If not, reverts the transaction. If pool is permissionless
     *         this function will just noop. */
    function verifyPermitInit(PoolSpecs.PoolCursor memory pool, address base, address quote, uint256 poolIdx)
        internal
    {
        if (pool.oracle_ != address(0)) {
            bool approved =
                ICrocPermitOracle(pool.oracle_).checkApprovedForCrocInit(lockHolder_, msg.sender, base, quote, poolIdx);
            require(approved, "Z");
        }
    }

    /* @notice Creates (or resets if previously existed) a new pool template associated
     *         with an arbitrary pool index. After calling, any pair's pool initialized
     *         at this index will be created using this template.
     *
     * @dev    Previously existing pools at this index will *not* be updated by this 
     *         call, and must be individually reset. This is only a consideration if the
     *         template is being reset, as a pool can't be created at an index beore a
     *         template exists.
     *
     * @param poolIdx The arbitrary index for which this template will be created. After
     *                calling, any user will be able to initialize a pool with this 
     *                template in any pair by using this pool index.
     * @param feeRate The pool's exchange fee as a percent of notional swapped. 
     *                Represented as a multiple of 0.0001%.
     * @param tickSize The tick grid size for range orders in the pool. (Template can
     *                 also be disabled by setting this to zero.)
     * @param jitThresh The minimum time (in seconds) a concentrated LP position must 
     *                  rest before it can be burned.
     * @param knockout  The knockout liquidity bit flags for the pool. (See KnockoutLiq library)
     * @param oracleFlags The permissioned oracle flags for the pool. */
    function setPoolTemplate(
        uint256 poolIdx,
        uint16 feeRate,
        uint16 tickSize,
        uint8 jitThresh,
        uint8 knockout,
        uint8 oracleFlags
    ) internal {
        PoolSpecs.Pool storage templ = templates_[poolIdx];
        templ.schema_ = PoolSpecs.BASE_SCHEMA;
        templ.feeRate_ = feeRate;
        templ.tickSize_ = tickSize;
        templ.jitThresh_ = jitThresh;
        templ.knockoutBits_ = knockout;
        templ.oracleFlags_ = oracleFlags;

        // If template is set to use a permissioned oracle, validate that the oracle address is a
        // valid oracle contract
        address oracle = PoolSpecs.oracleForPool(poolIdx, oracleFlags);
        if (oracle != address(0)) {
            require(oracle.code.length > 0 && ICrocPermitOracle(oracle).acceptsPermitOracle(), "Oracle");
        }
    }

    function disablePoolTemplate(uint256 poolIdx) internal {
        PoolSpecs.Pool storage templ = templates_[poolIdx];
        templ.schema_ = PoolSpecs.DISABLED_SCHEMA;
    }

    /* @notice Resets the parameters on a previously existing pool in a specific pair.
     *
     * @dev We do not allow the permitOracle to be changed after the pool has been 
     *      initialized. That would give the protocol authority too much power to 
     *      arbitrarily lock LPs out of their funds. 
     *
     * @param base The base-side token specification of the pair containing the pool.
     * @param quote The quote-side token specification of the pair containing the pool.
     * @param poolIdx The pool type index value. 
     * @param feeRate The pool's exchange fee as a percent of notional swapped. 
     *                Represented as a multiple of 0.0001%.
     * @param tickSize The tick grid size for range orders in the pool.
     * @param jitThresh The minimum time (in seconds) a concentrated LP position must 
     *                  rest before it can be burned.
     * @param knockoutBits The knockout liquiidity parameter bit flags for the pool. */
    function setPoolSpecs(
        address base,
        address quote,
        uint256 poolIdx,
        uint16 feeRate,
        uint16 tickSize,
        uint8 jitThresh,
        uint8 knockoutBits
    ) internal {
        PoolSpecs.Pool storage pool = selectPool(base, quote, poolIdx);
        pool.feeRate_ = feeRate;
        pool.tickSize_ = tickSize;
        pool.jitThresh_ = jitThresh;
        pool.knockoutBits_ = knockoutBits;
    }

    // 10 million represents a sensible upper bound on initial pool, considering that the highest
    // price token per wei is USDC and similar 6-digit stablecoins. So 10 million in that context
    // represents about $10 worth of burned value. Considering that the initial liquidity commitment
    // should be economic de minims, because it's permenately locked, we wouldn't want to be much
    // higher than this.
    uint128 constant MAX_INIT_POOL_LIQ = 10_000_000;

    /* @notice The creation of every new pool requires the pool initializer to 
     *         permanetely lock in a token amount of liquidity (possibly zero). This is
     *         set to be economically meaningless for normal cases but prevent the 
     *         creation of pools for tokens that don't exist or make it expensive to 
     *         create pools at extremely wrong prices. This function sets that liquidity
     *         ante value that determines how much liquidity must be locked at 
     *         initialization time. */
    function setNewPoolLiq(uint128 liqAnte) internal {
        require(liqAnte > 0 && liqAnte < MAX_INIT_POOL_LIQ, "Init liq");
        newPoolLiq_ = liqAnte;
    }

    // Since take rate is represented in 1/256, this represents a maximum possible take
    // rate of 50%.
    uint8 MAX_TAKE_RATE = 128;

    function setProtocolTakeRate(uint8 takeRate) internal {
        require(takeRate <= MAX_TAKE_RATE, "TR");
        protocolTakeRate_ = takeRate;
    }

    function setRelayerTakeRate(uint8 takeRate) internal {
        require(takeRate <= MAX_TAKE_RATE, "TR");
        relayerTakeRate_ = takeRate;
    }

    function resyncProtocolTake(address base, address quote, uint256 poolIdx) internal {
        PoolSpecs.Pool storage pool = selectPool(base, quote, poolIdx);
        pool.protocolTake_ = protocolTakeRate_;
    }

    /* @notice Sets the off-grid price improvement thresholds for a specific token. Once
     *         set this will apply to every pool in every pair over this token. The 
     *         stored settings for a token can be initialized, then later reset 
     *         arbitararily.
     *
     * @param token The token these settings apply to (if 0x0, they apply to native 
     *              Eth pairs)
     * @param unitTickCollateral The collateral threshold per off-grid tick.
     * @param awayTickTol The maximum ticks away from the current price that an off-grid
     *                    range order can apply. */
    function setPriceImprove(address token, uint128 unitTickCollateral, uint16 awayTickTol) internal {
        improves_[token].unitCollateral_ = unitTickCollateral;
        improves_[token].awayTicks_ = awayTickTol;
    }

    /* @notice This is called during the initialization of a new pool. It registers the
     *         pool for this pair and type in storage for later access. Note that the
     *         caller still needs to actually construct the curve, collect the required
     *         collateral, etc. All this does is storage the pool specs.
     * 
     * @param base The base-side token (or 0x0 for native Eth) defining the pair.
     * @param quote The quote-side token defining the pair.
     * @param poolIdx The pool type index for the newly created pool. The pool specs will
     *                be created from the current template for this index. (If no 
     *                template exists, this call will revert the transaction.)
     *
     * @return pool The pool specs associated with the newly created pool.
     * @return liqAnte The required amount of liquidity that the user must permanetely
     *                 lock to create the pool. (See setNewPoolLiq() above) */
    function registerPool(address base, address quote, uint256 poolIdx)
        internal
        returns (PoolSpecs.PoolCursor memory, uint128)
    {
        assertPoolFresh(base, quote, poolIdx);
        PoolSpecs.Pool memory template = queryTemplate(poolIdx);
        template.protocolTake_ = protocolTakeRate_;
        PoolSpecs.writePool(pools_, base, quote, poolIdx, template);
        return (queryPool(base, quote, poolIdx), newPoolLiq_);
    }

    /* @notice This returns the off-grid price improvement settings (if any) for the
     *         the side of the pair the user requests. (Or none, to save on gas,
     *         if the user doesn't explicitly request price improvement).
     *
     * @param req The user specificed price improvement request.
     * @param base The base-side token defining the pair.
     * @param quote The quote-side token defining the pair.
     * @return The price grid improvement thresholds (if any) for off-grid liquidity 
     *         positions. */
    function queryPriceImprove(Directives.PriceImproveReq memory req, address base, address quote)
        internal
        view
        returns (PriceGrid.ImproveSettings memory dest)
    {
        if (req.isEnabled_) {
            address token = req.useBaseSide_ ? base : quote;
            dest.inBase_ = req.useBaseSide_;
            dest.unitCollateral_ = improves_[token].unitCollateral_;
            dest.awayTicks_ = improves_[token].awayTicks_;
        }
    }

    /* @notice Looks up and returns the pool specs associated with the pair and pool type
     *
     * @dev If no pool exists, this call reverts the transaction.
     *
     * @param base The base-side token defining the pair.
     * @param quote The quote-side token defining the pair.
     * @param poolIdx The pool type index.
     * @return The current spec parameters for the pool. */
    function queryPool(address base, address quote, uint256 poolIdx)
        internal
        view
        returns (PoolSpecs.PoolCursor memory pool)
    {
        pool = PoolSpecs.queryPool(pools_, base, quote, poolIdx);
        require(isPoolInit(pool), "PI");
    }

    function assertPoolFresh(address base, address quote, uint256 poolIdx) internal view {
        PoolSpecs.PoolCursor memory pool = PoolSpecs.queryPool(pools_, base, quote, poolIdx);
        require(!isPoolInit(pool), "PF");
    }

    /* @notice Checks if a given position is JIT eligible based on its mint timestamp.
     *         If not, the transaction will revert.
     * 
     * @dev Because JIT window is capped at 8-bit integers, we can avoid the SLOAD
     *      for all positions older than 2550 seconds, which are the vast majority.
     *
     * @param posTime The block time the position was created or had its liquidity 
     *                increased.
     * @param poolIdx The hash index of the AMM curve pool. */
    function assertJitSafe(uint32 posTime, bytes32 poolIdx) internal view {
        uint32 JIT_UNIT_SECONDS = 10;
        uint32 elapsedSecs = SafeCast.timeUint32() - posTime;
        uint32 elapsedUnits = elapsedSecs / JIT_UNIT_SECONDS;
        if (elapsedUnits <= type(uint8).max) {
            require(elapsedUnits >= pools_[poolIdx].jitThresh_, "J");
        }
    }

    /* @notice Looks up and returns a storage pointer associated with the pair and pool 
     *         type.
     *
     * @param base The base-side token defining the pair.
     * @param quote The quote-side token defining the pair.
     * @param poolIdx The pool type index.
     * @return Storage reference to the specs for the pool. */
    function selectPool(address base, address quote, uint256 poolIdx)
        private
        view
        returns (PoolSpecs.Pool storage pool)
    {
        pool = PoolSpecs.selectPool(pools_, base, quote, poolIdx);
        require(isPoolInit(pool), "PI");
    }

    /* @notice Looks up and returns the pool template associated with the pool type 
     *         index. If no template exists (or it was disabled after initialization)
     *         this call reverts the transaction. */
    function queryTemplate(uint256 poolIdx) private view returns (PoolSpecs.Pool memory template) {
        template = templates_[poolIdx];
        require(isPoolInit(template), "PT");
    }

    /* @notice Returns true if the pool spec object represents an initailized pool 
     *         that hasn't been disabled. */
    function isPoolInit(PoolSpecs.Pool memory pool) private pure returns (bool) {
        require(pool.schema_ <= PoolSpecs.BASE_SCHEMA, "IPS");
        return pool.schema_ == PoolSpecs.BASE_SCHEMA;
    }

    /* @notice Returns true if the pool cursor represents an initailized pool that
     *         hasn't been disabled. */
    function isPoolInit(PoolSpecs.PoolCursor memory pool) private pure returns (bool) {
        require(pool.head_.schema_ <= PoolSpecs.BASE_SCHEMA, "IPS");
        return pool.head_.schema_ == PoolSpecs.BASE_SCHEMA;
    }
}

/* @title Position registrar mixin
 * @notice Tracks the individual positions of liquidity miners, including fee 
 *         accumulation checkpoints for fair distribution of rewards. */
contract PositionRegistrar is PoolRegistry {
    using SafeCast for uint256;
    using SafeCast for uint144;
    using CompoundMath for uint128;
    using LiquidityMath for uint64;
    using LiquidityMath for uint128;

    /* The six things we need to know for each concentrated liquidity position are:
     *    1) Owner
     *    2) The pool the position is on.
     *    3) Lower tick bound on the range
     *    4) Upper tick bound on the range
     *    5) Total liquidity
     *    6) Fee accumulation mileage for the position's range checkpointed at the last
     *       update. Used to correctly distribute in-range liquidity rewards.
     * Of these 1-4 constitute the unique key. If a user adds a new position with the
     * same owner and the same range, it can be represented by incrementing 5 and 
     * updating 6. */

    /* @notice Hashes the owner of an ambient liquidity position to the position key. */
    function encodePosKey(address owner, bytes32 poolIdx) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, poolIdx));
    }

    /* @notice Hashes the owner and concentrated liquidity range to the position key. */
    function encodePosKey(address owner, bytes32 poolIdx, int24 lowerTick, int24 upperTick)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(owner, poolIdx, lowerTick, upperTick));
    }

    /* @notice Returns the current position associated with the owner/range. If nothing
     *         exists the result will have zero liquidity. */
    function lookupPosition(address owner, bytes32 poolIdx, int24 lowerTick, int24 upperTick)
        internal
        view
        returns (RangePosition storage)
    {
        return positions_[encodePosKey(owner, poolIdx, lowerTick, upperTick)];
    }

    /* @notice Returns the current position associated with the owner's ambient 
     *         position. If nothing exists the result will have zero liquidity. */
    function lookupPosition(address owner, bytes32 poolIdx) internal view returns (AmbientPosition storage) {
        return ambPositions_[encodePosKey(owner, poolIdx)];
    }

    /* @notice Removes all or some liquidity associated with a position. Calculates
     *         the cumulative rewards since last update, and updates the fee mileage
     *         (if position still have active liquidity).
     *
     * @param owner The bytes32 owning the position.
     * @param poolIdx The hash key of the pool the position lives on.
     * @param lowerTick The 24-bit tick index constituting the lower range of the 
     *                  concentrated liquidity position.
     * @param upperTick The 24-bit tick index constituting the upper range of the 
     *                  concentrated liquidity position.
     * @param burnLiq The amount of liquidity to remove from the position. Caller is
     *                is responsible for making sure the position has at least this much
     *                liquidity in place.
     * @param feeMileage The up-to-date fee mileage associated with the range. If the
     *                   position is still active after this call, this new value will
     *                   be checkpointed on the position.
     *
     * @return rewards The rewards accumulated between the current and last checkpoined
     *                 fee mileage. */
    function burnPosLiq(
        address owner,
        bytes32 poolIdx,
        int24 lowerTick,
        int24 upperTick,
        uint128 burnLiq,
        uint64 feeMileage
    ) internal returns (uint64) {
        RangePosition storage pos = lookupPosition(owner, poolIdx, lowerTick, upperTick);
        assertJitSafe(pos.timestamp_, poolIdx);
        return decrementLiq(pos, burnLiq, feeMileage);
    }

    /* @notice Removes all or some liquidity associated with a an ambient position. 
     *         
     * @param owner The bytes32 owning the position.
     * @param poolIdx The hash key of the pool the position lives on.
     * @param burnLiq The amount of liquidity to remove from the position. Caller is free
     *                to oversize this number and it will just cap at the position size.
     * @param ambientGrowth The up-to-date ambient liquidity seed deflator for the curve.
     *
     * @return burnSeeds The total number of ambient seeds that have been removed with
     *                   this operation. */
    function burnPosLiq(address owner, bytes32 poolIdx, uint128 burnLiq, uint64 ambientGrowth)
        internal
        returns (uint128 burnSeeds)
    {
        AmbientPosition storage pos = lookupPosition(owner, poolIdx);
        burnSeeds = burnLiq.deflateLiqSeed(ambientGrowth);

        if (burnSeeds >= pos.seeds_) {
            burnSeeds = pos.seeds_;
            // Solidity optimizer should convert this to a single refunded SSTORE
            pos.seeds_ = 0;
            pos.timestamp_ = 0;
        } else {
            pos.seeds_ -= burnSeeds;
            // Decreasing liquidity does not lose time priority
        }
    }

    /* @notice Decrements a range order position with the amount of liquidity being
     *         burned, and calculates the incremental rewards mileage. */
    function decrementLiq(RangePosition storage pos, uint128 burnLiq, uint64 feeMileage)
        internal
        returns (uint64 rewards)
    {
        uint128 liq = pos.liquidity_;
        uint128 nextLiq = LiquidityMath.minusDelta(liq, burnLiq);

        rewards = feeMileage.deltaRewardsRate(pos.feeMileage_);

        if (nextLiq > 0) {
            // Partial burn. Check that it's allowed on this position.
            require(pos.atomicLiq_ == false, "OR");
            pos.liquidity_ = nextLiq;
            // No need to adjust the position's mileage checkpoint. Rewards are in per
            // unit of liquidity, so the pro-rata rewards of the remaining liquidity
            // (if any) remain unnaffected.
        } else {
            // Solidity optimizer should convert this to a single refunded SSTORE
            pos.liquidity_ = 0;
            pos.feeMileage_ = 0;
            pos.timestamp_ = 0;
            pos.atomicLiq_ = false;
        }
    }

    /* @notice Harvests all of the rewards on a concentrated liquidity position and 
     *         resets the accumulated fees to zero.
     *         
     * @param owner The bytes32 owning the position.
     * @param poolIdx The hash key of the pool the position lives on.
     * @param lowerTick The lower tick of the LP position
     * @param upperTick The upper tick of the LP position.
     * @param feeMileage The current accumulated fee rewards rate for the position range
     *
     * @return rewards The total number of ambient seeds to collect as rewards */
    function harvestPosLiq(address owner, bytes32 poolIdx, int24 lowerTick, int24 upperTick, uint64 feeMileage)
        internal
        returns (uint128 rewards)
    {
        RangePosition storage pos = lookupPosition(owner, poolIdx, lowerTick, upperTick);
        uint64 oldMileage = pos.feeMileage_;

        // Technically feeMileage should never be less than oldMileage, but we need to
        // handle it because it can happen due to fixed-point effects.
        // (See blendMileage() function.)
        if (feeMileage > oldMileage) {
            uint64 rewardsRate = feeMileage.deltaRewardsRate(oldMileage);
            rewards = FixedPoint.mulQ48(pos.liquidity_, rewardsRate).toUint128By144();
            pos.feeMileage_ = feeMileage;
        }
    }

    /* @notice Marks a flag on a speciic position that indicates that it's liquidity
     *         is atomic. I.e. the position size cannot be partially reduced, only
     *         removed entirely. */
    function markPosAtomic(address owner, bytes32 poolIdx, int24 lowTick, int24 highTick) internal {
        RangePosition storage pos = lookupPosition(owner, poolIdx, lowTick, highTick);
        pos.atomicLiq_ = true;
    }

    /* @notice Adds liquidity to a given concentrated liquidity position, creating the
     *         position if necessary.
     *
     * @param owner The bytes32 owning the position.
     * @param poolIdx The index of the pool the position belongs to
     * @param lowerTick The 24-bit tick index constituting the lower range of the 
     *                  concentrated liquidity position.
     * @param upperTick The 24-bit tick index constituting the upper range of the 
     *                  concentrated liquidity position.
     * @param liqAdd The amount of liquidity to add to the position. If no liquidity 
     *               previously exists, position will be created.
     * @param feeMileage The up-to-date fee mileage associated with the range. If the
     *                   position will be checkpointed with this value. */
    function mintPosLiq(
        address owner,
        bytes32 poolIdx,
        int24 lowerTick,
        int24 upperTick,
        uint128 liqAdd,
        uint64 feeMileage
    ) internal {
        RangePosition storage pos = lookupPosition(owner, poolIdx, lowerTick, upperTick);
        incrementPosLiq(pos, liqAdd, feeMileage);
    }

    /* @notice Adds ambient liquidity to a give position, creating a new position tracker
     *         if necessry.
     *         
     * @param owner The address of the owner of the liquidity position.
     * @param poolIdx The hash key of the pool the position lives on.
     * @param liqAdd The amount of liquidity to add to the position.
     * @param ambientGrowth The up-to-date ambient liquidity seed deflator for the curve.
     *
     * @return seeds The total number of ambient seeds that this incremental liquidity
     *               corresponds to. */
    function mintPosLiq(address owner, bytes32 poolIdx, uint128 liqAdd, uint64 ambientGrowth)
        internal
        returns (uint128 seeds)
    {
        AmbientPosition storage pos = lookupPosition(owner, poolIdx);
        seeds = liqAdd.deflateLiqSeed(ambientGrowth);
        pos.seeds_ = pos.seeds_.addLiq(seeds);
        pos.timestamp_ = SafeCast.timeUint32(); // Increase liquidity loses time priority.
    }

    /* @notice Increments a range order position with the amount of liquidity being
     *         burned. If necessary blends a weighted average rewards mileage with the
     *         previous position. */
    function incrementPosLiq(RangePosition storage pos, uint128 liqAdd, uint64 feeMileage) private {
        uint128 liq = pos.liquidity_;
        uint64 oldMileage;

        if (liq > 0) {
            oldMileage = pos.feeMileage_;
        } else {
            oldMileage = 0;
        }

        uint128 liqNext = liq.addLiq(liqAdd);
        uint64 mileage = feeMileage.blendMileage(liqAdd, oldMileage, liq);
        uint32 stamp = SafeCast.timeUint32();

        // Below should get optimized to a single SSTORE...
        pos.liquidity_ = liqNext;
        pos.feeMileage_ = mileage;
        pos.timestamp_ = stamp;
    }
}

/* @title Liquidity Curve Mixin
 * @notice Tracks the state of the locally stable constant product AMM liquid curve
 *         for the pool. Applies any adjustment to the curve as needed, either from
 *         new or removed positions or pre-determined liquidity bumps that occur
 *         when crossing tick boundaries. */
contract LiquidityCurve is StorageLayout {
    using SafeCast for uint128;
    using SafeCast for uint192;
    using SafeCast for uint144;
    using LiquidityMath for uint128;
    using CurveMath for uint128;
    using CurveMath for CurveMath.CurveState;

    /* @notice Copies the current state of the curve in EVM storage to a memory clone.
     * @dev    Use for light-weight gas ergonomics when iterarively operating on the 
     *         curve. But it's the callers responsibility to persist the changes back
     *         to storage when complete. */
    function snapCurve(bytes32 poolIdx) internal view returns (CurveMath.CurveState memory curve) {
        curve = curves_[poolIdx];
        require(curve.priceRoot_ > 0);
    }

    /* @notice Snapshots the curve for pool initialization operation.
     * @dev    This only skips the initialization check from snapCurve() does *not* assert
     *         that the curve was not previously initialized. That's the caller's 
     *         responsibility */
    function snapCurveInit(bytes32 poolIdx) internal view returns (CurveMath.CurveState memory) {
        return curves_[poolIdx];
    }

    /* @notice Snapshots the curve to memory, but verifies that the price occurs within
     *         a pre-specified price range. If not, reverts the entire transaction. */
    function snapCurveInRange(bytes32 poolIdx, uint128 minPrice, uint128 maxPrice)
        internal
        view
        returns (CurveMath.CurveState memory curve)
    {
        curve = snapCurve(poolIdx);
        require(curve.priceRoot_ >= minPrice && curve.priceRoot_ <= maxPrice, "RC");
    }

    /* @notice Writes a CurveState modified in memory back into persistent storage. 
     *         Use for the working copy from snapCurve when finalized. */
    function commitCurve(bytes32 poolIdx, CurveMath.CurveState memory curve) internal {
        curves_[poolIdx] = curve;
    }

    /* @notice Called whenever a user adds a fixed amount of concentrated liquidity
     *         to the curve. This must be called regardless of whether the liquidity is
     *         in-range at the current curve price or not.
     * @dev After being called this will alter the curve to reflect the new liquidity, 
     *      but it's the callers responsibility to make sure that the required 
     *      collateral is actually collected.
     *
     * @param curve The liquidity curve object that range liquidity will be added to.
     * @param liquidity The amount of liquidity being added. Represented in the form of
     *                  sqrt(X*Y) where X,Y are the virtual reserves of the tokens in a
     *                  constant product AMM. Calculate the same whether in-range or not.
     * @param lowerTick The tick index corresponding to the bottom of the concentrated 
     *                  liquidity range.
     * @param upperTick The tick index corresponding to the bottom of the concentrated 
     *                  liquidity range.
     *
     * @return base - The amount of base token collateral that must be collected 
     *                following the addition of this liquidity.
     * @return quote - The amount of quote token collateral that must be collected 
     *                 following the addition of this liquidity. */
    function liquidityReceivable(CurveMath.CurveState memory curve, uint128 liquidity, int24 lowerTick, int24 upperTick)
        internal
        pure
        returns (uint128, uint128)
    {
        (uint128 base, uint128 quote, bool inRange) = liquidityFlows(curve.priceRoot_, liquidity, lowerTick, upperTick);
        bumpConcentrated(curve, liquidity, inRange);
        return chargeConservative(base, quote, inRange);
    }

    /* @notice Equivalent to above, but used when adding non-range bound constant 
     *         product ambient liquidity.
     * @dev Like above, it's the caller's responsibility to collect the necessary 
     *      collateral to add to the pool.
     *
     * @param curve The liquidity curve object that ambient liquidity will be added to.
     * @param seeds The number of ambient seeds being added. Note that this is 
     *              denominated as seeds *not* liquidity. The amount of liquidity
     *              contributed will be based on the current seed->liquidity conversion
     *              rate on the curve. (See CurveMath.sol.)
     * @return  The base and quote token flows from the user required to add this amount
     *          of liquidity to the curve. */
    function liquidityReceivable(CurveMath.CurveState memory curve, uint128 seeds)
        internal
        pure
        returns (uint128, uint128)
    {
        (uint128 base, uint128 quote) = liquidityFlows(curve, seeds);
        bumpAmbient(curve, seeds);
        return chargeConservative(base, quote, true);
    }

    /* @notice Called when liquidity is being removed from the pool Adjusts the curve
     *         accordingly and calculates the amount of collateral payable to the user.
     *         This must be called for all removes regardless of whether the liquidity
     *         is in range or not.
     * @dev It's the caller's responsibility to actually return the collateral to the 
     *      user. This method will only calculate what's owed, but won't actually pay it.
     *
     * 
     * @param curve The liquidity curve object that concentrated liquidity will be 
     *              removed from.
     * @param liquidity The amount of liquidity being removed, whether in-range or not.
     *                  Represented in the form of sqrt(X*Y) where x,Y are the virtual
     *                  reserves of a constant product AMM.
     * @param rewardRate The total cumulative earned but unclaimed rewards on the staked
     *                   liquidity. Used to increment the payout with the rewards, and
     *                   burn the ambient liquidity tied to the rewards. (See 
     *                   CurveMath.sol for more.) Represented as a 128-bit fixed point
     *                   cumulative growth rate of ambient seeds per unit of liquidity.
     * @param lowerTick The tick index corresponding to the bottom of the concentrated 
     *                  liquidity range.
     * @param upperTick The tick index corresponding to the bottom of the concentrated 
     *                  liquidity range.
     *
     * @return base - The amount of base token collateral that can be paid out following
     *                the removal of the liquidity. Always rounded down to favor 
     *                collateral stability.
     * @return quote - The amount of base token collateral that can be paid out following
     *                the removal of the liquidity. Always rounded down to favor 
     *                collateral stability. */
    function liquidityPayable(
        CurveMath.CurveState memory curve,
        uint128 liquidity,
        uint64 rewardRate,
        int24 lowerTick,
        int24 upperTick
    ) internal pure returns (uint128 base, uint128 quote) {
        (base, quote) = liquidityPayable(curve, liquidity, lowerTick, upperTick);
        (base, quote) = stackRewards(base, quote, curve, liquidity, rewardRate);
    }

    function stackRewards(
        uint128 base,
        uint128 quote,
        CurveMath.CurveState memory curve,
        uint128 liquidity,
        uint64 rewardRate
    ) internal pure returns (uint128, uint128) {
        if (rewardRate > 0) {
            // Round down reward sees on payout, in contrast to rounding them up on
            // incremental accumulation (see CurveAssimilate.sol). This mathematicaly
            // guarantees that we never try to burn more tokens than exist on the curve.
            uint128 rewards = FixedPoint.mulQ48(liquidity, rewardRate).toUint128By144();

            if (rewards > 0) {
                (uint128 baseRewards, uint128 quoteRewards) = liquidityPayable(curve, rewards);
                base += baseRewards;
                quote += quoteRewards;
            }
        }
        return (base, quote);
    }

    /* @notice The same as the above liquidityPayable() but called when accumulated 
     *         rewards are zero. */
    function liquidityPayable(CurveMath.CurveState memory curve, uint128 liquidity, int24 lowerTick, int24 upperTick)
        internal
        pure
        returns (uint128 base, uint128 quote)
    {
        bool inRange;
        (base, quote, inRange) = liquidityFlows(curve.priceRoot_, liquidity, lowerTick, upperTick);
        bumpConcentrated(curve, -(liquidity.toInt128Sign()), inRange);
    }

    /* @notice Same as above liquidityPayable() but used for non-range based ambient
     *         constant product liquidity.
     *
     * @param curve The liquidity curve object that ambient liquidity will be 
     *              removed from.
     * @param seeds The number of ambient seeds being added. Note that this is 
     *              denominated as seeds *not* liquidity. The amount of liquidity
     *              contributed will be based on the current seed->liquidity conversion
     *              rate on the curve. (See CurveMath.sol.) 
     * @return base - The amount of base token collateral that can be paid out following
     *                the removal of the liquidity. Always rounded down to favor 
     *                collateral stability.
     * @return quote - The amount of base token collateral that can be paid out following
     *                the removal of the liquidity. Always rounded down to favor 
     *                collateral stability. */
    function liquidityPayable(CurveMath.CurveState memory curve, uint128 seeds)
        internal
        pure
        returns (uint128 base, uint128 quote)
    {
        (base, quote) = liquidityFlows(curve, seeds);
        bumpAmbient(curve, -(seeds.toInt128Sign()));
    }

    function liquidityHeldPayable(
        CurveMath.CurveState memory curve,
        uint128 liquidity,
        uint64 rewards,
        KnockoutLiq.KnockoutPosLoc memory loc
    ) internal pure returns (uint128 base, uint128 quote) {
        (base, quote) = liquidityHeldPayable(liquidity, loc);
        (base, quote) = stackRewards(base, quote, curve, liquidity, rewards);
    }

    function liquidityHeldPayable(uint128 liquidity, KnockoutLiq.KnockoutPosLoc memory loc)
        internal
        pure
        returns (uint128 base, uint128 quote)
    {
        (uint128 bidPrice, uint128 askPrice) = translateTickRange(loc.lowerTick_, loc.upperTick_);
        if (loc.isBid_) {
            quote = liquidity.deltaQuote(bidPrice, askPrice);
        } else {
            base = liquidity.deltaBase(bidPrice, askPrice);
        }
    }

    /* @notice Directly increments the ambient liquidity on the curve. */
    function bumpAmbient(CurveMath.CurveState memory curve, uint128 seedDelta) private pure {
        bumpAmbient(curve, seedDelta.toInt128Sign());
    }

    /* @notice Directly increments the ambient liquidity on the curve. */
    function bumpAmbient(CurveMath.CurveState memory curve, int128 seedDelta) private pure {
        curve.ambientSeeds_ = curve.ambientSeeds_.addDelta(seedDelta);
    }

    /* @notice Directly increments the concentrated liquidity on the curve, depending
     *         on whether it's in range. */
    function bumpConcentrated(CurveMath.CurveState memory curve, uint128 liqDelta, bool inRange) private pure {
        bumpConcentrated(curve, liqDelta.toInt128Sign(), inRange);
    }

    /* @notice Directly increments the concentrated liquidity on the curve, depending
     *         on whether it's in range. */
    function bumpConcentrated(CurveMath.CurveState memory curve, int128 liqDelta, bool inRange) private pure {
        if (inRange) {
            curve.concLiq_ = curve.concLiq_.addDelta(liqDelta);
        }
    }

    /* @notice Calculates the liquidity flows associated with the concentrated liquidity
     *         from a range order.
     * @dev Uses fixed-point math that rounds down up to 2 wei from the true real valued
     *   flows. Safe to pay this flow, but when pool is receiving caller must make sure
     *   to round up for collateral safety. */
    function liquidityFlows(uint128 price, uint128 liquidity, int24 bidTick, int24 askTick)
        private
        pure
        returns (uint128 baseDebit, uint128 quoteDebit, bool inRange)
    {
        (uint128 bidPrice, uint128 askPrice) = translateTickRange(bidTick, askTick);

        if (price < bidPrice) {
            quoteDebit = liquidity.deltaQuote(bidPrice, askPrice);
        } else if (price >= askPrice) {
            baseDebit = liquidity.deltaBase(bidPrice, askPrice);
        } else {
            quoteDebit = liquidity.deltaQuote(price, askPrice);
            baseDebit = liquidity.deltaBase(bidPrice, price);
            inRange = true;
        }
    }

    /* @notice Calculates the liquidity flows associated with the concentrated liquidity
     *         from a range order.    
     * @dev Uses fixed-point math that rounds down at each division. Because there are
     *   divisions, max precision loss is under 2 wei. Safe to pay this flow, but when
     *   when pool is receiving, caller must make sure to round up for collateral 
     *   safety. */
    function liquidityFlows(CurveMath.CurveState memory curve, uint128 seeds)
        private
        pure
        returns (uint128 baseDebit, uint128 quoteDebit)
    {
        uint128 liq = CompoundMath.inflateLiqSeed(seeds, curve.seedDeflator_);
        baseDebit = FixedPoint.mulQ64(liq, curve.priceRoot_).toUint128By192();
        quoteDebit = FixedPoint.divQ64(liq, curve.priceRoot_).toUint128By192();
    }

    /* @notice Called exactly once at the initializing of the pool. Initializes the
     *         liquidity curve at an arbitrary price.
     * @dev Throws error if price was already initialized. 
     *
     * @param curve   The liquidity curve for the pool being initialized.
     * @param priceRoot - Square root of the price. Represented as Q64.64 fixed point. */
    function initPrice(CurveMath.CurveState memory curve, uint128 priceRoot) internal pure {
        int24 tick = TickMath.getTickAtSqrtRatio(priceRoot);
        require(tick >= TickMath.MIN_TICK && tick <= TickMath.MAX_TICK, "R");

        require(curve.priceRoot_ == 0, "N");
        curve.priceRoot_ = priceRoot;
    }

    /* @notice Converts a price tick index range into a range of prices. */
    function translateTickRange(int24 lowerTick, int24 upperTick)
        private
        pure
        returns (uint128 bidPrice, uint128 askPrice)
    {
        require(upperTick > lowerTick);
        require(lowerTick >= TickMath.MIN_TICK);
        require(upperTick <= TickMath.MAX_TICK);
        bidPrice = TickMath.getSqrtRatioAtTick(lowerTick);
        askPrice = TickMath.getSqrtRatioAtTick(upperTick);
    }

    // Need to support at least 2 wei of precision round down when calculating quote
    // token reserve deltas. (See CurveMath's deltaPriceQuote() function.) 4 gives us a
    // safe cushion and is economically meaningless.
    uint8 constant TOKEN_ROUND = 4;

    /* @notice Rounds liquidity flows up in cases where we want to be conservative with
     *         collateral. */
    function chargeConservative(uint128 liqBase, uint128 liqQuote, bool inRange)
        private
        pure
        returns (uint128, uint128)
    {
        return (
            (liqBase > 0 || inRange) ? liqBase + TOKEN_ROUND : 0, (liqQuote > 0 || inRange) ? liqQuote + TOKEN_ROUND : 0
        );
    }
}

/// @title BitMath
/// @dev This library provides functionality for computing bit properties of an unsigned integer
library BitMath {
    /// @notice Returns the index of the most significant bit of the number,
    ///     where the least significant bit is at index 0 and the most significant bit is at index 255
    /// @dev The function satisfies the property:
    ///     x >= 2**mostSignificantBit(x) and x < 2**(mostSignificantBit(x)+1)
    /// @param x the value for which to compute the most significant bit, must be greater than 0
    /// @return r the index of the most significant bit
    function mostSignificantBit(uint256 x) internal pure returns (uint8 r) {
        // Set to unchecked, but the original UniV3 library was written in a pre-checked version of Solidity
        unchecked {
            require(x > 0);

            if (x >= 0x100000000000000000000000000000000) {
                x >>= 128;
                r += 128;
            }
            if (x >= 0x10000000000000000) {
                x >>= 64;
                r += 64;
            }
            if (x >= 0x100000000) {
                x >>= 32;
                r += 32;
            }
            if (x >= 0x10000) {
                x >>= 16;
                r += 16;
            }
            if (x >= 0x100) {
                x >>= 8;
                r += 8;
            }
            if (x >= 0x10) {
                x >>= 4;
                r += 4;
            }
            if (x >= 0x4) {
                x >>= 2;
                r += 2;
            }
            if (x >= 0x2) r += 1;
        }
    }

    /// @notice Returns the index of the least significant bit of the number,
    ///     where the least significant bit is at index 0 and the most significant bit is at index 255
    /// @dev The function satisfies the property:
    ///     (x & 2**leastSignificantBit(x)) != 0 and (x & (2**(leastSignificantBit(x)) - 1)) == 0)
    /// @param x the value for which to compute the least significant bit, must be greater than 0
    /// @return r the index of the least significant bit
    function leastSignificantBit(uint256 x) internal pure returns (uint8 r) {
        // Set to unchecked, but the original UniV3 library was written in a pre-checked version of Solidity
        unchecked {
            require(x > 0);

            r = 255;
            if (x & type(uint128).max > 0) {
                r -= 128;
            } else {
                x >>= 128;
            }
            if (x & type(uint64).max > 0) {
                r -= 64;
            } else {
                x >>= 64;
            }
            if (x & type(uint32).max > 0) {
                r -= 32;
            } else {
                x >>= 32;
            }
            if (x & type(uint16).max > 0) {
                r -= 16;
            } else {
                x >>= 16;
            }
            if (x & type(uint8).max > 0) {
                r -= 8;
            } else {
                x >>= 8;
            }
            if (x & 0xf > 0) {
                r -= 4;
            } else {
                x >>= 4;
            }
            if (x & 0x3 > 0) {
                r -= 2;
            } else {
                x >>= 2;
            }
            if (x & 0x1 > 0) r -= 1;
        }
    }
}

/* @title Tick bitmap library
 *
 * @notice Tick bitmaps are used for the tracking of tick initialization
 *    state over a 256-bit interval. Tick indices are 24-bit integer, so
 *    this library provides for 3-layers of recursive 256-bit bitmaps. Each
 *    layer covers the first (lobby), middle (mezzanine) or last (terminus) 
 *    8-bits in the 24-bit index.
 *
 * @dev Note that the bitmap library works with the full set of possible int24
 *      values. Whereas other parts of the protocol set a MIN_TICK and MAX_TICK
 *      that are well within the type bounds of int24. It's the responsibility of
 *      calling code to assure that ticks being set are within the MIN_TICK and
 *      MAX_TICK, and this library does *not* provide those checks. */
library Bitmaps {
    /* @notice Transforms the bitmap so the first or last N bits are set to zero.
     * @param bitmap - The original 256-bit bitmap object.
     * @param shift - The number N of slots in the bitmap to mask to zero.
     * @param right - If true mask the N bits from right to left. Otherwise from
     *                left to right.
     * @return The bitmap with N bits (on the right or left side) masked. */
    function truncateBitmap(uint256 bitmap, uint16 shift, bool right) internal pure returns (uint256) {
        return right ? (bitmap >> shift) << shift : (bitmap << shift) >> shift;
    }

    /* @notice - Determine the index of the first set bit in the bitmap starting
     *    after N bits from the right or the left.
     * @param bitmap - The 256-bit bitmap object.
     * @param shift - Exclude the first shift N bits from the index result.
     * @param right - If true find the first set bit starting from the right
     *   (least significant bit as EVM is big endian). Otherwise from the lefft.
     * @return idx - The index of the matching set bit. Index position is always
     *   left indexed starting at zero regardless of the @right parameter.
     * @return spills - If no matching set bit is found, this return value is set to
     *   true. */
    function bitAfterTrunc(uint256 bitmap, uint16 shift, bool right) internal pure returns (uint8 idx, bool spills) {
        bitmap = truncateBitmap(bitmap, shift, right);
        spills = (bitmap == 0);
        if (!spills) {
            idx = right ? BitMath.leastSignificantBit(bitmap) : BitMath.mostSignificantBit(bitmap);
        }
    }

    /* @notice Returns true if the bitmap's Nth bit slot is set.
     * @param bitmap - The 256 bit bitmap object.
     * @param pos - The bitmap index to check. Value is left indexed starting at zero.
     * @return True if the bit is set. */
    function isBitSet(uint256 bitmap, uint8 pos) internal pure returns (bool) {
        (uint256 idx, bool spill) = bitAfterTrunc(bitmap, pos, true);
        return !spill && idx == pos;
    }

    /* @notice Converts a signed integer bitmap index to an unsigned integer. */
    function castBitmapIndex(int8 x) internal pure returns (uint8) {
        unchecked {
            return x >= 0
                ? uint8(x) + 128 // max(int8(x)) + 128 <= 255, so this never overflows
                : uint8(uint16(int16(x) + 128)); // min(int8(x)) + 128 >= 0 (and less than 255)
        }
    }

    /* @notice Converts an unsigned integer bitmap index to a signed integer. */
    function uncastBitmapIndex(uint8 x) internal pure returns (int8) {
        unchecked {
            return x < 128
                ? int8(int16(uint16(x)) - 128) // max(uint8) - 128 <= 127, so never overflows int8
                : int8(x - 128); // min(uint8) - 128  >= -128, so never underflows int8
        }
    }

    /* @notice Extracts the 8-bit tick lobby index from the full 24-bit tick index. */
    function lobbyKey(int24 tick) internal pure returns (int8) {
        return int8(tick >> 16); // 24-bit int shifted by 16 bits will always fit in 8 bits
    }

    /* @notice Extracts the 16-bit tick root from the full 24-bit tick 
     * index. */
    function mezzKey(int24 tick) internal pure returns (int16) {
        return int16(tick >> 8); // 24-bit int shifted by 8 bits will always fit in 16 bits
    }

    /* @notice Extracts the 8-bit lobby bits (the last 8-bits) from the full 24-bit tick 
     * index. Result can be used to index on a lobby bitmap. */
    function lobbyBit(int24 tick) internal pure returns (uint8) {
        return castBitmapIndex(lobbyKey(tick));
    }

    /* @notice Extracts the 8-bit mezznine bits (the middle 8-bits) from the full 24-bit 
     * tick index. Result can be used to index on a mezzanine bitmap. */
    function mezzBit(int24 tick) internal pure returns (uint8) {
        return uint8(uint16(mezzKey(tick) % 256)); // Modulo 256 will always <= 255, and fit in uint8
    }

    /* @notice Extracts the 8-bit terminus bits (the last 8-bits) from the full 24-bit 
     * tick index. Result can be used to index on a terminus bitmap. */
    function termBit(int24 tick) internal pure returns (uint8) {
        return uint8(uint24(tick % 256)); // Modulo 256 will always <= 255, and fit in uint8
    }

    /* @notice Determines the next shift bump from a starting terminus value. Note for 
     *   upper the barrier is always to the right. For lower it's on the tick. This is
     *   because bumps always occur at the start of the tick.
     *
     * @param tick - The full 24-bit tick index.
     * @param isUpper - If true, shift and index from left-to-right. Otherwise right-to-
     *   left.
     * @return - Returns the bumped terminus bit indexed directionally based on param 
     *   isUpper. Can be 256, if the terminus bit occurs at the last slot. */
    function termBump(int24 tick, bool isUpper) internal pure returns (uint16) {
        unchecked {
            uint8 bit = termBit(tick);
            // Bump moves up for upper, but occurs at the bottom of the same tick for lower.
            uint16 shiftTerm = isUpper ? 1 : 0;
            return uint16(bitRelate(bit, isUpper)) + shiftTerm;
        }
    }

    /* @notice Converts a directional bitmap position, to a cardinal bitmap position. For
     *   example the 20th bit for a sell (right-to-left) would be the 235th bit in
     *   the bitmap. 
     * @param bit - The directional-oriented index in the 256-bit bitmap.
     * @param isUpper - If true, the direction is left-to-right, if false right-to-left.
     * @return The cardinal (left-to-right) index in the bitmap. */
    function bitRelate(uint8 bit, bool isUpper) internal pure returns (uint8) {
        unchecked {
            return isUpper ? bit : (255 - bit); // 255 minus uint8 will never underflow
        }
    }

    /* @notice Converts a 16-bit tick base and an 8-bit terminus tick to a full 24-bit
     *   tick index. */
    function weldMezzTerm(int16 mezzBase, uint8 termBitArg) internal pure returns (int24) {
        unchecked {
            // First term will always be <= 0x8FFF00 and second term (as a uint8) will always
            // be positive and <= 0xFF. Therefore the sum will never overflow int24
            return (int24(mezzBase) << 8) + int24(uint24(termBitArg));
        }
    }

    /* @notice Converts an 8-bit lobby index and an 8-bit mezzanine bit into a 16-bit 
     *   tick base root. */
    function weldLobbyMezz(int8 lobbyIdx, uint8 mezzBitArg) internal pure returns (int16) {
        unchecked {
            // First term will always be <= 0x8F00 and second term (as a uint) will always
            // be positive and <= 0xFF. Therefore the sum will never overflow int24
            return (int16(lobbyIdx) << 8) + int16(uint16(mezzBitArg));
        }
    }

    /* @notice Converts an 8-bit lobby index, an 8-bit mezzanine bit, and an 8-bit
     *   terminus bit into a full 24-bit tick index. */
    function weldLobbyMezzTerm(int8 lobbyIdx, uint8 mezzBitArg, uint8 termBitArg) internal pure returns (int24) {
        unchecked {
            // First term will always be  <= 0x8F0000. Second term, starting as a uint8
            // will always be positive and <= 0xFF00. Thir term will always be positive
            // and <= 0xFF. Therefore the sum will never overflow int24
            return (int24(lobbyIdx) << 16) + (int24(uint24(mezzBitArg)) << 8) + int24(uint24(termBitArg));
        }
    }

    /* @notice Converts an 8-bit lobby index, an 8-bit mezzanine bit, and an 8-bit
     *   terminus bit into a full 24-bit tick index. */
    function weldLobbyPosMezzTerm(uint8 lobbyWord, uint8 mezzBitArg, uint8 termBitArg) internal pure returns (int24) {
        return weldLobbyMezzTerm(Bitmaps.uncastBitmapIndex(lobbyWord), mezzBitArg, termBitArg);
    }

    /* @notice The minimum and maximum 24-bit integers are used to represent -/+ 
     *   infinity range. We have to reserve these bits as non-standard range for when
     *   price shifts past the last representable tick.
     * @param tick The tick index value being tested
     * @return True if the tick index represents a positive or negative infinity. */
    function isTickFinite(int24 tick) internal pure returns (bool) {
        return tick > type(int24).min && tick < type(int24).max;
    }

    /* @notice Returns the zero horizon point for the full 24-bit tick index. */
    function zeroTick(bool isUpper) internal pure returns (int24) {
        return isUpper ? type(int24).max : type(int24).min;
    }

    /* @notice Returns the zero horizon point equivalent for the first 16-bits of the 
     *    tick index. */
    function zeroMezz(bool isUpper) internal pure returns (int16) {
        return isUpper ? type(int16).max : type(int16).min;
    }

    /* @notice Returns the zero point equivalent for the terminus bit (last 8-bits) of
     *    the tick index. */
    function zeroTerm(bool isUpper) internal pure returns (uint8) {
        return isUpper ? type(uint8).max : 0;
    }
}

/* @title Tick census mixin.
 * 
 * @notice Tracks which tick indices have an active liquidity bump, making it gas
 *   efficient for random read and writes, and to find the next bump tick boundary
 *   on the curve. 
 * 
 * @dev Note that this mixin works with the full set of possible int24 values.
 *      Whereas other parts of the protocol set a MIN_TICK and MAX_TICK that are
 *      that well within the type bounds of int24. It's the responsibility of
 *      calling code to assure that ticks being set are within the MIN_TICK and
 *      MAX_TICK, and this library does *not* provide those checks. */
contract TickCensus is StorageLayout {
    using Bitmaps for uint256;
    using Bitmaps for int24;

    /* Tick positions are stored in three layers of 8-bit/256-slot bitmaps. Recursively
     * they indicate whether any given 24-bit tick index is active.

     * The first layer (lobby) represents the 8-bit tick root. If we did store this
     * layer, we'd only need a single 256-bit bitmap per pool. However we do *not*
     * store this layer, because it adds an unnecessary SLOAD/SSTORE operation on
     * almost all operations. Instead users can query this layer by checking whether
     * mezzanine key is set for each bit. The tradeoff is that lobby bitmap queries
     * are no longer O(1) random access but O(N) seeks. However at most there are 256
     * SLOAD on a lobby-layer seek, and spills at the lobby layer are rare (moving 
     * between multiple lobby bits requires a 65,000% price change). This gas tradeoff
     *  is virtually always justified. 
     *
     * The second layer (mezzanine) maps whether each 16-bit tick root is set. An 
     * entry will be set if and only if *any* tick index in the 8-bit range is set. 
     * Because there are 256^2 slots, this is represented as a map from the first 8-
     * bits in the root to individual 8-bit/256-slot bitmaps for the middle 8-bits 
     * at that root. 
     *
     * The final layer (terminus) directly maps whether individual tick indices are
     * set. Because there are 256^3 possible slots, this is represnted as a mapping 
     * from the first 16-bit tick root to individual 8-bit/256-slot bitmaps of the 
     * terminal 8-bits within that root. */

    /* @notice Returns the associated bitmap for the terminus position (bottom layer) 
     *         of the tick index. 
     * @param poolIdx The hash key associated with the pool being queried.
     * @param tick A price tick index within the neighborhood that we want the bitmap for.
     * @return The bitmap of the 256-tick neighborhood. */
    function terminusBitmap(bytes32 poolIdx, int24 tick) internal view returns (uint256) {
        bytes32 idx = encodeTerm(poolIdx, tick);
        return terminus_[idx];
    }

    /* @notice Returns the associated bitmap for the mezzanine position (middle layer) 
     *         of the tick index.
     * @param poolIdx The hash key associated with the pool being queried.
     * @param tick A price tick index within the neighborhood that we want the bitmap for.
     * @return The mezzanine bitmap of the 65536-tick neighborhood. */
    function mezzanineBitmap(bytes32 poolIdx, int24 tick) internal view returns (uint256) {
        bytes32 idx = encodeMezz(poolIdx, tick);
        return mezzanine_[idx];
    }

    /* @notice Returns true if the tick index is currently set. Indicates an tick exists
     *         at that index. 
     * @param poolIdx The hash key associated with the pool being queried.
     * @param tick The price tick that we're querying. */
    function hasTickBookmark(bytes32 poolIdx, int24 tick) internal view returns (bool) {
        uint256 bitmap = terminusBitmap(poolIdx, tick);
        uint8 term = tick.termBit();
        return bitmap.isBitSet(term);
    }

    /* @notice Mark the tick index as active.
     * @dev Idempotent. Can be called repeatedly on previously initialized ticks.
     * @param poolIdx The hash key associated with the pool being queried.
     * @param tick The price tick that we're marking as enabled. */
    function bookmarkTick(bytes32 poolIdx, int24 tick) internal {
        uint256 mezzMask = 1 << tick.mezzBit();
        uint256 termMask = 1 << tick.termBit();
        mezzanine_[encodeMezz(poolIdx, tick)] |= mezzMask;
        terminus_[encodeTerm(poolIdx, tick)] |= termMask;
    }

    /* @notice Unset the tick index as no longer active. Take care of any book keeping
     *   related to the recursive bitmap levels.
     * @dev Idempontent. Can be called repeatedly even if tick was previously 
     *   forgotten.
     * @param poolIdx The hash key associated with the pool being queried.
     * @param tick The price tick that we're marking as disabled. */
    function forgetTick(bytes32 poolIdx, int24 tick) internal {
        uint256 mezzMask = ~(1 << tick.mezzBit());
        uint256 termMask = ~(1 << tick.termBit());

        bytes32 termIdx = encodeTerm(poolIdx, tick);
        uint256 termUpdate = terminus_[termIdx] & termMask;
        terminus_[termIdx] = termUpdate;

        if (termUpdate == 0) {
            bytes32 mezzIdx = encodeMezz(poolIdx, tick);
            uint256 mezzUpdate = mezzanine_[mezzIdx] & mezzMask;
            mezzanine_[mezzIdx] = mezzUpdate;
        }
    }

    /* @notice Finds an inner-bound conservative liquidity tick boundary based on
     *   the terminus map at a starting tick point. Because liquidity actually bumps
     *   at the bottom of the tick, the result is assymetric on direction. When seeking
     *   an upper barrier, it'll be the tick that we cross into. For lower barriers, it's
     *   the tick that we cross out of, and therefore could even be the starting tick.
     * 
     * @dev For gas efficiency this method only looks at a previously loaded terminus
     *   bitmap. Often for moves of that size we don't even need to look past the 
     *   terminus boundary. So there's no point doing a mezzanine layer seek unless we
     *   end up needing it.
     *
     * @param poolIdx The hash key associated with the pool being queried.
     * @param isUpper - If true indicates that we're looking for an upper boundary.
     * @param startTick - The current tick index that we're finding the boundary from.
     *
     * @return boundTick - The tick index that we can conservatively move to without 
     *    potentially hitting any currently active liquidity bump points.
     * @return isSpill - If true indicates that the boundary represents the end of the
     *    inner terminus bitmap neighborhood. Based on this we have to actually check whether
     *     we've reached teh true end of the liquidity range, or just the end of the known
     *     neighborhood.  */
    function pinBitmap(bytes32 poolIdx, bool isUpper, int24 startTick)
        internal
        view
        returns (int24 boundTick, bool isSpill)
    {
        uint256 termBitmap = terminusBitmap(poolIdx, startTick);
        uint16 shiftTerm = startTick.termBump(isUpper);
        int16 tickMezz = startTick.mezzKey();
        (boundTick, isSpill) = pinTermMezz(isUpper, shiftTerm, tickMezz, termBitmap);
    }

    /* @notice Formats the tick bit horizon index and sets the flag for whether it
    *          represents whether the seeks spills over the terminus neighborhood */
    function pinTermMezz(bool isUpper, uint16 shiftTerm, int16 tickMezz, uint256 termBitmap)
        private
        pure
        returns (int24 nextTick, bool spillBit)
    {
        (uint8 nextTerm, bool spillTrunc) = termBitmap.bitAfterTrunc(shiftTerm, isUpper);
        spillBit = doesSpillBit(isUpper, spillTrunc, termBitmap);
        nextTick = spillBit ? spillOverPin(isUpper, tickMezz) : Bitmaps.weldMezzTerm(tickMezz, nextTerm);
    }

    /* @notice Returns true if the tick seek reaches the end of the inner terminus 
     *      bitmap neighborhood. If that happens, it's like reaching the end of the map.
     *      It's returned as the boundary point, but the the user must be aware that the tick
     *      may or may not represent an active liquidity tick and check accordingly. */
    function doesSpillBit(bool isUpper, bool spillTrunc, uint256 termBitmap) private pure returns (bool spillBit) {
        if (isUpper) {
            spillBit = spillTrunc;
        } else {
            bool bumpAtFloor = termBitmap.isBitSet(0);
            spillBit = bumpAtFloor ? false : spillTrunc;
        }
    }

    /* @notice Formats the censored horizon tick index when the seek has spilled out of 
     *         the terminus bitmap neighborhood. */
    function spillOverPin(bool isUpper, int16 tickMezz) private pure returns (int24) {
        if (isUpper) {
            return tickMezz == Bitmaps.zeroMezz(isUpper)
                ? Bitmaps.zeroTick(isUpper)
                : Bitmaps.weldMezzTerm(tickMezz + 1, Bitmaps.zeroTerm(!isUpper));
        } else {
            return Bitmaps.weldMezzTerm(tickMezz, 0);
        }
    }

    /* @notice Determines the next tick bump boundary tick starting using recursive
     *   bitmap lookup. Follows the same up/down assymetry as pinBitmap(). Upper bump
     *   is the tick being crossed *into*, lower bump is the tick being crossed *out of*
     *
     * @dev This is a much more gas heavy operation because it recursively looks 
     *   though all three layers of bitmaps. It should only be called if pinBitmap()
     *   can't find the boundary in the terminus layer.
     *
     * @param poolIdx The hash key associated with the pool being queried.
     * @param borderTick - The current tick that we want to seek a tick liquidity
     *   boundary from. For defined behavior this tick must occur at the border of
     *   terminus bitmap. For lower borders, must be the tick from the start of the byte.
     *   For upper borders, must be the tick past the end of the byte. Any spill result 
     *   from pinTermMezz() is safe.
     * @param isUpper - The direction of the boundary. If true seek an upper boundary.
     *
     * @return (int24) - The tick index of the next tick boundary with an active 
     *   liquidity bump. The result is assymetric boundary for upper/lower ticks. */
    function seekMezzSpill(bytes32 poolIdx, int24 borderTick, bool isUpper) internal view returns (int24) {
        if (isUpper && borderTick == type(int24).max) return type(int24).max;
        if (!isUpper && borderTick == type(int24).min) return type(int24).min;

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

    /* @notice Seeks the next tick bitmap by searching in the adjacent neighborhood. */
    function seekAtTerm(bytes32 poolIdx, uint8 lobbyBit, uint8 mezzBit, bool isUpper)
        private
        view
        returns (int24, bool)
    {
        uint256 neighborBitmap = terminus_[encodeTermWord(poolIdx, lobbyBit, mezzBit)];
        (uint8 termBit, bool spills) = neighborBitmap.bitAfterTrunc(0, isUpper);
        if (spills) return (0, true);
        return (Bitmaps.weldLobbyPosMezzTerm(lobbyBit, mezzBit, termBit), false);
    }

    /* @notice Seeks the next tick bitmap by searching in the current mezzanine 
     *         neighborhood.
     * @dev This covers a span of 65 thousand ticks, so should capture most cases. */
    function seekAtMezz(bytes32 poolIdx, uint8 lobbyBit, uint8 mezzBorder, bool isUpper)
        private
        view
        returns (int24, bool)
    {
        uint256 neighborMezz = mezzanine_[encodeMezzWord(poolIdx, lobbyBit)];
        uint8 mezzShift = Bitmaps.bitRelate(mezzBorder, isUpper);
        (uint8 mezzBit, bool spills) = neighborMezz.bitAfterTrunc(mezzShift, isUpper);
        if (spills) return (0, true);
        return seekAtTerm(poolIdx, lobbyBit, mezzBit, isUpper);
    }

    /* @notice Used when the tick is not contained in the mezzanine. We walk through the
     *         the mezzanine tick bitmaps one by one until we find an active tick bit. */
    function seekOverLobby(bytes32 poolIdx, uint8 lobbyBit, bool isUpper) private view returns (int24) {
        return isUpper ? seekLobbyUp(poolIdx, lobbyBit) : seekLobbyDown(poolIdx, lobbyBit);
    }

    /* Unlike the terminus and mezzanine layer, we don't store a bitmap at the lobby
     * layer. Instead we iterate through the top-level bits until we find an active
     * mezzanine. This requires a maximum of 256 iterations, and can be gas intensive.
     * However moves at this level represent 65,000% price changes and are very rare. */
    function seekLobbyUp(bytes32 poolIdx, uint8 lobbyBit) private view returns (int24) {
        uint8 MAX_MEZZ = 0;
        unchecked {
            // Unchecked because we want idx to wrap around to 0, to check all 256 bits
            for (uint8 i = lobbyBit + 1; i > 0; ++i) {
                (int24 tick, bool spills) = seekAtMezz(poolIdx, i, MAX_MEZZ, true);
                if (!spills) return tick;
            }
        }
        return Bitmaps.zeroTick(true);
    }

    /* Same logic as seekLobbyUp(), but the inverse direction. */
    function seekLobbyDown(bytes32 poolIdx, uint8 lobbyBit) private view returns (int24) {
        uint8 MIN_MEZZ = 255;
        unchecked {
            // Unchecked because we want idx to wrap around to 255, to check all 256 bits
            for (uint8 i = lobbyBit - 1; i < 255; --i) {
                (int24 tick, bool spills) = seekAtMezz(poolIdx, i, MIN_MEZZ, false);
                if (!spills) return tick;
            }
        }
        return Bitmaps.zeroTick(false);
    }

    /* @notice Splits out the lobby bits and the mezzanine bits from the 24-bit price
     *         tick index associated with the type of border tick used in seekMezzSpill()
     *         call */
    function rootsForBorder(int24 borderTick, bool isUpper) private pure returns (uint8 lobbyBit, uint8 mezzBit) {
        // Because pinTermMezz returns a border *on* the previous bitmap, we need to
        // decrement by one to get the seek starting point.
        int24 pinTick = isUpper ? borderTick : (borderTick - 1);
        lobbyBit = pinTick.lobbyBit();
        mezzBit = pinTick.mezzBit();
    }

    /* @notice Encodes the hash key for the mezzanine neighborhood of the tick. */
    function encodeMezz(bytes32 poolIdx, int24 tick) private pure returns (bytes32) {
        int8 wordPos = tick.lobbyKey();
        return keccak256(abi.encodePacked(poolIdx, wordPos));
    }

    /* @notice Encodes the hash key for the terminus neighborhood of the tick. */
    function encodeTerm(bytes32 poolIdx, int24 tick) private pure returns (bytes32) {
        int16 wordPos = tick.mezzKey();
        return keccak256(abi.encodePacked(poolIdx, wordPos));
    }

    /* @notice Encodes the hash key for the mezzanine neighborhood of the first 8-bits
     *         of a tick index. (This is all that's needed to determine mezzanine.) */
    function encodeMezzWord(bytes32 poolIdx, int8 lobbyPos) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(poolIdx, lobbyPos));
    }

    /* @notice Encodes the hash key for the mezzanine neighborhood of the first 8-bits
     *         of a tick index. (This is all that's needed to determine mezzanine.) */
    function encodeMezzWord(bytes32 poolIdx, uint8 lobbyPos) private pure returns (bytes32) {
        return encodeMezzWord(poolIdx, Bitmaps.uncastBitmapIndex(lobbyPos));
    }

    /* @notice Encodes the hash key for the terminus neighborhood of the first 16-bits
     *         of a tick index. (This is all that's needed to determine terminus.) */
    function encodeTermWord(bytes32 poolIdx, uint8 lobbyPos, uint8 mezzPos) private pure returns (bytes32) {
        int16 mezzIdx = Bitmaps.weldLobbyMezz(Bitmaps.uncastBitmapIndex(lobbyPos), mezzPos);
        return keccak256(abi.encodePacked(poolIdx, mezzIdx));
    }
}

library console {
    address constant CONSOLE_ADDRESS = address(0x000000000000000000636F6e736F6c652e6c6f67);

    function _sendLogPayload(bytes memory payload) private view {
        uint256 payloadLength = payload.length;
        address consoleAddress = CONSOLE_ADDRESS;
        /// @solidity memory-safe-assembly
        assembly {
            let payloadStart := add(payload, 32)
            let r := staticcall(gas(), consoleAddress, payloadStart, payloadLength, 0, 0)
        }
    }

    function log() internal view {
        _sendLogPayload(abi.encodeWithSignature("log()"));
    }

    function logInt(int256 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(int)", p0));
    }

    function logUint(uint256 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
    }

    function logString(string memory p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string)", p0));
    }

    function logBool(bool p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
    }

    function logAddress(address p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address)", p0));
    }

    function logBytes(bytes memory p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes)", p0));
    }

    function logBytes1(bytes1 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes1)", p0));
    }

    function logBytes2(bytes2 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes2)", p0));
    }

    function logBytes3(bytes3 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes3)", p0));
    }

    function logBytes4(bytes4 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes4)", p0));
    }

    function logBytes5(bytes5 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes5)", p0));
    }

    function logBytes6(bytes6 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes6)", p0));
    }

    function logBytes7(bytes7 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes7)", p0));
    }

    function logBytes8(bytes8 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes8)", p0));
    }

    function logBytes9(bytes9 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes9)", p0));
    }

    function logBytes10(bytes10 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes10)", p0));
    }

    function logBytes11(bytes11 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes11)", p0));
    }

    function logBytes12(bytes12 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes12)", p0));
    }

    function logBytes13(bytes13 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes13)", p0));
    }

    function logBytes14(bytes14 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes14)", p0));
    }

    function logBytes15(bytes15 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes15)", p0));
    }

    function logBytes16(bytes16 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes16)", p0));
    }

    function logBytes17(bytes17 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes17)", p0));
    }

    function logBytes18(bytes18 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes18)", p0));
    }

    function logBytes19(bytes19 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes19)", p0));
    }

    function logBytes20(bytes20 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes20)", p0));
    }

    function logBytes21(bytes21 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes21)", p0));
    }

    function logBytes22(bytes22 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes22)", p0));
    }

    function logBytes23(bytes23 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes23)", p0));
    }

    function logBytes24(bytes24 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes24)", p0));
    }

    function logBytes25(bytes25 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes25)", p0));
    }

    function logBytes26(bytes26 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes26)", p0));
    }

    function logBytes27(bytes27 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes27)", p0));
    }

    function logBytes28(bytes28 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes28)", p0));
    }

    function logBytes29(bytes29 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes29)", p0));
    }

    function logBytes30(bytes30 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes30)", p0));
    }

    function logBytes31(bytes31 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes31)", p0));
    }

    function logBytes32(bytes32 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bytes32)", p0));
    }

    function log(uint256 p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
    }

    function log(string memory p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string)", p0));
    }

    function log(bool p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
    }

    function log(address p0) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address)", p0));
    }

    function log(uint256 p0, uint256 p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint)", p0, p1));
    }

    function log(uint256 p0, string memory p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string)", p0, p1));
    }

    function log(uint256 p0, bool p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool)", p0, p1));
    }

    function log(uint256 p0, address p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address)", p0, p1));
    }

    function log(string memory p0, uint256 p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint)", p0, p1));
    }

    function log(string memory p0, string memory p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string)", p0, p1));
    }

    function log(string memory p0, bool p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool)", p0, p1));
    }

    function log(string memory p0, address p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address)", p0, p1));
    }

    function log(bool p0, uint256 p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint)", p0, p1));
    }

    function log(bool p0, string memory p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string)", p0, p1));
    }

    function log(bool p0, bool p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool)", p0, p1));
    }

    function log(bool p0, address p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address)", p0, p1));
    }

    function log(address p0, uint256 p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint)", p0, p1));
    }

    function log(address p0, string memory p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string)", p0, p1));
    }

    function log(address p0, bool p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool)", p0, p1));
    }

    function log(address p0, address p1) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address)", p0, p1));
    }

    function log(uint256 p0, uint256 p1, uint256 p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint)", p0, p1, p2));
    }

    function log(uint256 p0, uint256 p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,string)", p0, p1, p2));
    }

    function log(uint256 p0, uint256 p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool)", p0, p1, p2));
    }

    function log(uint256 p0, uint256 p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,address)", p0, p1, p2));
    }

    function log(uint256 p0, string memory p1, uint256 p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,uint)", p0, p1, p2));
    }

    function log(uint256 p0, string memory p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,string)", p0, p1, p2));
    }

    function log(uint256 p0, string memory p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,bool)", p0, p1, p2));
    }

    function log(uint256 p0, string memory p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,address)", p0, p1, p2));
    }

    function log(uint256 p0, bool p1, uint256 p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint)", p0, p1, p2));
    }

    function log(uint256 p0, bool p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,string)", p0, p1, p2));
    }

    function log(uint256 p0, bool p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool)", p0, p1, p2));
    }

    function log(uint256 p0, bool p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,address)", p0, p1, p2));
    }

    function log(uint256 p0, address p1, uint256 p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,uint)", p0, p1, p2));
    }

    function log(uint256 p0, address p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,string)", p0, p1, p2));
    }

    function log(uint256 p0, address p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,bool)", p0, p1, p2));
    }

    function log(uint256 p0, address p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,address)", p0, p1, p2));
    }

    function log(string memory p0, uint256 p1, uint256 p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,uint)", p0, p1, p2));
    }

    function log(string memory p0, uint256 p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,string)", p0, p1, p2));
    }

    function log(string memory p0, uint256 p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,bool)", p0, p1, p2));
    }

    function log(string memory p0, uint256 p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,address)", p0, p1, p2));
    }

    function log(string memory p0, string memory p1, uint256 p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,uint)", p0, p1, p2));
    }

    function log(string memory p0, string memory p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,string)", p0, p1, p2));
    }

    function log(string memory p0, string memory p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,bool)", p0, p1, p2));
    }

    function log(string memory p0, string memory p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,address)", p0, p1, p2));
    }

    function log(string memory p0, bool p1, uint256 p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint)", p0, p1, p2));
    }

    function log(string memory p0, bool p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,string)", p0, p1, p2));
    }

    function log(string memory p0, bool p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool)", p0, p1, p2));
    }

    function log(string memory p0, bool p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,address)", p0, p1, p2));
    }

    function log(string memory p0, address p1, uint256 p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,uint)", p0, p1, p2));
    }

    function log(string memory p0, address p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,string)", p0, p1, p2));
    }

    function log(string memory p0, address p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,bool)", p0, p1, p2));
    }

    function log(string memory p0, address p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,address)", p0, p1, p2));
    }

    function log(bool p0, uint256 p1, uint256 p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint)", p0, p1, p2));
    }

    function log(bool p0, uint256 p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,string)", p0, p1, p2));
    }

    function log(bool p0, uint256 p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool)", p0, p1, p2));
    }

    function log(bool p0, uint256 p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,address)", p0, p1, p2));
    }

    function log(bool p0, string memory p1, uint256 p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint)", p0, p1, p2));
    }

    function log(bool p0, string memory p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,string)", p0, p1, p2));
    }

    function log(bool p0, string memory p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool)", p0, p1, p2));
    }

    function log(bool p0, string memory p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,address)", p0, p1, p2));
    }

    function log(bool p0, bool p1, uint256 p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint)", p0, p1, p2));
    }

    function log(bool p0, bool p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string)", p0, p1, p2));
    }

    function log(bool p0, bool p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool)", p0, p1, p2));
    }

    function log(bool p0, bool p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address)", p0, p1, p2));
    }

    function log(bool p0, address p1, uint256 p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint)", p0, p1, p2));
    }

    function log(bool p0, address p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,string)", p0, p1, p2));
    }

    function log(bool p0, address p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool)", p0, p1, p2));
    }

    function log(bool p0, address p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,address)", p0, p1, p2));
    }

    function log(address p0, uint256 p1, uint256 p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,uint)", p0, p1, p2));
    }

    function log(address p0, uint256 p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,string)", p0, p1, p2));
    }

    function log(address p0, uint256 p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,bool)", p0, p1, p2));
    }

    function log(address p0, uint256 p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,address)", p0, p1, p2));
    }

    function log(address p0, string memory p1, uint256 p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,uint)", p0, p1, p2));
    }

    function log(address p0, string memory p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,string)", p0, p1, p2));
    }

    function log(address p0, string memory p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,bool)", p0, p1, p2));
    }

    function log(address p0, string memory p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,address)", p0, p1, p2));
    }

    function log(address p0, bool p1, uint256 p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint)", p0, p1, p2));
    }

    function log(address p0, bool p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,string)", p0, p1, p2));
    }

    function log(address p0, bool p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool)", p0, p1, p2));
    }

    function log(address p0, bool p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,address)", p0, p1, p2));
    }

    function log(address p0, address p1, uint256 p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,uint)", p0, p1, p2));
    }

    function log(address p0, address p1, string memory p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,string)", p0, p1, p2));
    }

    function log(address p0, address p1, bool p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,bool)", p0, p1, p2));
    }

    function log(address p0, address p1, address p2) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,address)", p0, p1, p2));
    }

    function log(uint256 p0, uint256 p1, uint256 p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,uint)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, uint256 p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, uint256 p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, uint256 p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, string memory p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,uint)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, bool p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,uint)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, address p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,uint)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, uint256 p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, uint256 p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,uint)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, uint256 p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, uint256 p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, uint256 p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, string memory p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,string,uint)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,string,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,string,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,string,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, bool p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,uint)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, address p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,address,uint)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,address,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,address,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, string memory p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,string,address,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, uint256 p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,uint)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, uint256 p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, uint256 p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, uint256 p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, string memory p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,uint)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, bool p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,uint)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, address p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,uint)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, bool p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, uint256 p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,uint)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, uint256 p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, uint256 p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, uint256 p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, string memory p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,string,uint)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,string,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,string,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,string,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, bool p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,uint)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,address)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, address p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,address,uint)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,address,string)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,address,bool)", p0, p1, p2, p3));
    }

    function log(uint256 p0, address p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(uint,address,address,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, uint256 p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, uint256 p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, uint256 p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, uint256 p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, string memory p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,string,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,string,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,string,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,string,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, bool p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, address p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,address,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,address,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,address,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, uint256 p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,uint,address,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, uint256 p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,uint,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, uint256 p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,uint,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, uint256 p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,uint,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, uint256 p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,uint,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, string memory p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,string,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,string,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,string,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,string,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, bool p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,bool,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,bool,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,bool,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,bool,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, address p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,address,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,address,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,address,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, string memory p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,string,address,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, uint256 p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, uint256 p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, uint256 p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, uint256 p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, string memory p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,string,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,string,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,string,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,string,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, bool p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, address p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,address,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,address,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,address,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, bool p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,bool,address,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, uint256 p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,uint,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, uint256 p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,uint,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, uint256 p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,uint,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, uint256 p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,uint,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, string memory p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,string,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,string,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,string,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,string,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, bool p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,bool,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,bool,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,bool,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,bool,address)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, address p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,address,uint)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,address,string)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,address,bool)", p0, p1, p2, p3));
    }

    function log(string memory p0, address p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(string,address,address,address)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, uint256 p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, uint256 p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,string)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, uint256 p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, uint256 p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,address)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, string memory p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,string)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,address)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, bool p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,string)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,address)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, address p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,string)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, uint256 p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,address)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, uint256 p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, uint256 p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,string)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, uint256 p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, uint256 p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,address)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, string memory p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,string,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,string,string)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,string,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,string,address)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, bool p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,string)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,address)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, address p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,address,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,address,string)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,address,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, string memory p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,string,address,address)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, uint256 p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, uint256 p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,string)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, uint256 p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, uint256 p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,address)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, string memory p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,string)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,address)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, bool p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,string)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,address)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, address p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,string)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, bool p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,address)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, uint256 p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, uint256 p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,string)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, uint256 p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, uint256 p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,address)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, string memory p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,string,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,string,string)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,string,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,string,address)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, bool p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,string)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,address)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, address p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,address,uint)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,address,string)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,address,bool)", p0, p1, p2, p3));
    }

    function log(bool p0, address p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(bool,address,address,address)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, uint256 p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,uint)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, uint256 p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,string)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, uint256 p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,bool)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, uint256 p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,address)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, string memory p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,string,uint)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,string,string)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,string,bool)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,string,address)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, bool p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,uint)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,string)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,bool)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,address)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, address p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,address,uint)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,address,string)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,address,bool)", p0, p1, p2, p3));
    }

    function log(address p0, uint256 p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,uint,address,address)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, uint256 p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,uint,uint)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, uint256 p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,uint,string)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, uint256 p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,uint,bool)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, uint256 p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,uint,address)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, string memory p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,string,uint)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,string,string)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,string,bool)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,string,address)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, bool p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,bool,uint)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,bool,string)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,bool,bool)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,bool,address)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, address p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,address,uint)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,address,string)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,address,bool)", p0, p1, p2, p3));
    }

    function log(address p0, string memory p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,string,address,address)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, uint256 p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,uint)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, uint256 p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,string)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, uint256 p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,bool)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, uint256 p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,address)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, string memory p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,string,uint)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,string,string)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,string,bool)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,string,address)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, bool p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,uint)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,string)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,bool)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,address)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, address p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,address,uint)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,address,string)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,address,bool)", p0, p1, p2, p3));
    }

    function log(address p0, bool p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,bool,address,address)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, uint256 p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,uint,uint)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, uint256 p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,uint,string)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, uint256 p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,uint,bool)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, uint256 p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,uint,address)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, string memory p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,string,uint)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, string memory p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,string,string)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, string memory p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,string,bool)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, string memory p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,string,address)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, bool p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,bool,uint)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, bool p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,bool,string)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, bool p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,bool,bool)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, bool p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,bool,address)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, address p2, uint256 p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,address,uint)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, address p2, string memory p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,address,string)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, address p2, bool p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,address,bool)", p0, p1, p2, p3));
    }

    function log(address p0, address p1, address p2, address p3) internal view {
        _sendLogPayload(abi.encodeWithSignature("log(address,address,address,address)", p0, p1, p2, p3));
    }
}

/* @title Level Book Mixin
 * @notice Mixin contract that tracks the aggregate liquidity bumps and in-range reward
 *         accumulators on a per-tick basis. */
contract LevelBook is TickCensus {
    using SafeCast for uint128;
    using LiquidityMath for uint128;
    using LiquidityMath for uint96;

    /* Book level structure exists one-to-one on a tick basis (though could possibly be
     * zero-valued). For each tick we have to track three values:
     *    bidLots_ - The change to concentrated liquidity that's added to the AMM curve when
     *               price moves into the tick from below, and removed when price moves
     *               into the tick from above. Denominated in lot-units which are 1024 multiples
     *               of liquidity units.
     *    askLots_ - The change to concentrated liquidity that's added to the AMM curve when
     *               price moves into the tick from above, and removed when price moves
     *               into the tick from below. Denominated in lot-units which are 1024 multiples
     *               of liquidity units.
     *    feeOdometer_ - The liquidity fee rewards accumulator that's checkpointed 
     *       whenever the price crosses the tick boundary. Used to calculate the 
     *       cumulative fee rewards on any arbitrary lower-upper tick range. This is
     *       generically represented as a per-liquidity unit 128-bit fixed point 
     *       cumulative growth rate. */

    /* @notice Called when the curve price moves through the tick boundary. Performs
     *         the necessary accumulator checkpointing and deriving the liquidity bump.
     *
     * @dev    Note that this function call is *not* idempotent. It's the callers 
     *         responsibility to only call once per tick cross direction. Otherwise 
     *         behavior is undefined. This is safe to call with non-initialized zero
     *         ticks but should generally be avoided for gas efficiency reasons.
     *
     * @param poolIdx - The hash index of the pool being traded on.
     * @param tick - The 24-bit tick index being crossed.
     * @param isBuy - If true indicates that price is crossing the tick boundary from 
     *                 below. If false, means tick is being crossed from above. 
     * @param feeGlobal - The up-to-date global fee reward accumulator value. Used to
     *                    checkpoint the tick rewards for calculating accumulated rewards
     *                    in a range. Represented as 128-bit fixed point cumulative 
     *                    growth rate per unit of liquidity.
     *
     * @return liqDelta - The net change in concentrated liquidity that should be applied
     *                    to the AMM curve following this level cross.
     * @return knockoutFlag - Indicates that the liquidity of the cross level has a 
     *                        knockout flag toggled. Upstream caller should handle 
     *                        appropriately */
    function crossLevel(bytes32 poolIdx, int24 tick, bool isBuy, uint64 feeGlobal)
        internal
        returns (int128 liqDelta, bool knockoutFlag)
    {
        BookLevel storage lvl = fetchLevel(poolIdx, tick);
        int128 crossDelta = LiquidityMath.netLotsOnLiquidity(lvl.bidLots_, lvl.askLots_);

        liqDelta = isBuy ? crossDelta : -crossDelta;

        if (feeGlobal != lvl.feeOdometer_) {
            lvl.feeOdometer_ = feeGlobal - lvl.feeOdometer_;
        }

        knockoutFlag = isBuy ? lvl.askLots_.hasKnockoutLiq() : lvl.bidLots_.hasKnockoutLiq();
    }

    /* @notice Retrieves the level book state associated with the tick. */
    function levelState(bytes32 poolIdx, int24 tick) internal view returns (BookLevel memory) {
        return levels_[keccak256(abi.encodePacked(poolIdx, tick))];
    }

    /* @notice Retrieves a storage pointer to the level associated with the tick. */
    function fetchLevel(bytes32 poolIdx, int24 tick) internal view returns (BookLevel storage) {
        return levels_[keccak256(abi.encodePacked(poolIdx, tick))];
    }

    /* @notice Deletes the level at the tick. */
    function deleteLevel(bytes32 poolIdx, int24 tick) private {
        delete levels_[keccak256(abi.encodePacked(poolIdx, tick))];
    }

    /* @notice Adds the liquidity associated with a new range order into the associated
     *         book levels, initializing the level structs if necessary.
     * 
     * @param poolIdx - The index of the pool the liquidity is being added to.
     * @param midTick - The tick index associated with the current price of the AMM curve
     * @param bidTick - The tick index for the lower bound of the range order.
     * @param askTick - The tick index for the upper bound of the range order.
     * @param lots - The amount of liquidity (in 1024 unit lots) being added by the range order.
     * @param feeGlobal - The up-to-date global fee rewards growth accumulator. 
     *    Represented as 128-bit fixed point growth rate.
     *
     * @return feeOdometer - Returns the current fee reward accumulator value for the
     *    range specified by the order. This is necessary, so we consumers of this mixin
     *    can subtract the rewards accumulated before the order was added. */
    function addBookLiq(bytes32 poolIdx, int24 midTick, int24 bidTick, int24 askTick, uint96 lots, uint64 feeGlobal)
        internal
        returns (uint64 feeOdometer)
    {
        // Make sure to init before add, because init logic relies on pre-add liquidity
        initLevel(poolIdx, midTick, bidTick, feeGlobal);
        initLevel(poolIdx, midTick, askTick, feeGlobal);

        addBid(poolIdx, bidTick, lots);
        addAsk(poolIdx, askTick, lots);
        feeOdometer = clockFeeOdometer(poolIdx, midTick, bidTick, askTick, feeGlobal);
    }

    /* @notice Call when removing liquidity associated with a specific range order.
     *         Decrements the associated tick levels as necessary.
     *
     * @param poolIdx - The index of the pool the liquidity is being removed from.
     * @param midTick - The tick index associated with the current price of the AMM curve
     * @param bidTick - The tick index for the lower bound of the range order.
     * @param askTick - The tick index for the upper bound of the range order.
     * @param liq - The amount of liquidity being added by the range order.
     * @param feeGlobal - The up-to-date global fee rewards growth accumulator. 
     *    Represented as 128-bit fixed point growth rate.
     *
     * @return feeOdometer - Returns the current fee reward accumulator value for the
     *    range specified by the order. Note that this returns the accumulated rewards
     *    from the range history, including *before* the order was added. It's the 
     *    downstream user's responsibility to adjust this value with the odometer clock
     *    from addBookLiq to correctly calculate the rewards accumulated over the 
     *    lifetime of the order. */
    function removeBookLiq(bytes32 poolIdx, int24 midTick, int24 bidTick, int24 askTick, uint96 lots, uint64 feeGlobal)
        internal
        returns (uint64 feeOdometer)
    {
        bool deleteBid = removeBid(poolIdx, bidTick, lots);
        bool deleteAsk = removeAsk(poolIdx, askTick, lots);
        feeOdometer = clockFeeOdometer(poolIdx, midTick, bidTick, askTick, feeGlobal);

        if (deleteBid) deleteLevel(poolIdx, bidTick);
        if (deleteAsk) deleteLevel(poolIdx, askTick);
    }

    /* @notice Initializes a new level, including marking the tick as active in the 
     *         bitmap, if the level doesn't previously exist. */
    function initLevel(bytes32 poolIdx, int24 midTick, int24 tick, uint64 feeGlobal) private {
        BookLevel storage lvl = fetchLevel(poolIdx, tick);
        if (lvl.bidLots_ == 0 && lvl.askLots_ == 0) {
            if (tick >= midTick) {
                lvl.feeOdometer_ = feeGlobal;
            }
            bookmarkTick(poolIdx, tick);
        }
    }

    /* @notice Increments bid liquidity on a previously existing level. */
    function addBid(bytes32 poolIdx, int24 tick, uint96 incrLots) private {
        BookLevel storage lvl = fetchLevel(poolIdx, tick);
        uint96 prevLiq = lvl.bidLots_;
        uint96 newLiq = prevLiq.addLots(incrLots);
        lvl.bidLots_ = newLiq;
    }

    /* @notice Increments ask liquidity on a previously existing level. */
    function addAsk(bytes32 poolIdx, int24 tick, uint96 incrLots) private {
        BookLevel storage lvl = fetchLevel(poolIdx, tick);
        uint96 prevLiq = lvl.askLots_;
        uint96 newLiq = prevLiq.addLots(incrLots);
        lvl.askLots_ = newLiq;
    }

    /* @notice Decrements bid liquidity on a level, and also removes the level from
     *          the tick bitmap if necessary. */
    function removeBid(bytes32 poolIdx, int24 tick, uint96 subLots) private returns (bool) {
        BookLevel storage lvl = fetchLevel(poolIdx, tick);
        uint96 prevLiq = lvl.bidLots_;
        uint96 newLiq = prevLiq.minusLots(subLots);

        // A level should only be marked inactive in the tick bitmap if *both* bid and
        // ask liquidity are zero.
        lvl.bidLots_ = newLiq;
        if (newLiq == 0 && lvl.askLots_ == 0) {
            forgetTick(poolIdx, tick);
            return true;
        }
        return false;
    }

    /* @notice Decrements ask liquidity on a level, and also removes the level from
     *          the tick bitmap if necessary. */
    function removeAsk(bytes32 poolIdx, int24 tick, uint96 subLots) private returns (bool) {
        BookLevel storage lvl = fetchLevel(poolIdx, tick);
        uint96 prevLiq = lvl.askLots_;
        uint96 newLiq = prevLiq.minusLots(subLots);

        lvl.askLots_ = newLiq;
        if (newLiq == 0 && lvl.bidLots_ == 0) {
            forgetTick(poolIdx, tick);
            return true;
        }
        return false;
    }

    /* @notice Calculates the current accumulated fee rewards in a given concentrated
     *         liquidity tick range. The difference between this value at two different
     *         times is guaranteed to reflect the accumulated rewards in the tick range
     *         between those two times.
     *
     *         For more explanation on how the fee rewards accumulated is calculated for
     *         a given range order, reference the documenation at [docs/FeeOdometer.md]
     *         in the project repository.
     *
     * @dev This returned result only has meaning when compared against the result
     *      from the same method call on the same range at a different time. Any
     *      given range could have an arbitrary offset relative to the pool's actual
     *      cumulative rewards.
     *
     * @param poolIdx The hash key specifying the pool being operated on.
     * @param currentTick The price tick of the curve's current price
     * @param lowerTick The prick tick of the lower boundary of the range order
     * @param upperTick The prick tick of the upper boundary of the range order
     * @param feeGlobal The cumulative rewards accumulated to a single unit of 
     *                  concentrated liquidity that was active since pool inception.
     *
     * @return The cumulative growth rate to a single unit of concentrated liquidity
     *         within the range. (Adjusted for an arbitrary offset that stays consistent
     *         over time. Only use this number to compare growth in the range over two
     *         points in time) */
    function clockFeeOdometer(bytes32 poolIdx, int24 currentTick, int24 lowerTick, int24 upperTick, uint64 feeGlobal)
        internal
        view
        returns (uint64)
    {
        uint64 feeLower = pivotFeeBelow(poolIdx, lowerTick, currentTick, feeGlobal);
        uint64 feeUpper = pivotFeeBelow(poolIdx, upperTick, currentTick, feeGlobal);

        // This is unchecked because we often rely on circular overflow arithmetic
        // when ticks are initialized at different times. Remember the output of this
        // function is only used to compare across time.
        unchecked {
            return feeUpper - feeLower;
        }
    }

    /* @dev Internally we checkpoint the last global accumulator value from the last
     *      time the level was crossed. Because fees can only accumulate when price
     *      is in range, the checkpoint represents the global fees that accumulated
     *      on the outside of the tick level. (Though this may be faked for fees that
     *      that accumulated prior to level initialization. It doesn't matter, because
     *      all we use this value for is calculating the delta of fee accumulation 
     *      between two different post-initialization points in time.)
     *
     *      For more explanation on how the per-tick fee odometer related to the 
     *      cumulative fees in a give range, reference the documenation at 
     *      [docs/FeeOdometer.md] in the project repository. */
    function pivotFeeBelow(bytes32 poolIdx, int24 lvlTick, int24 currentTick, uint64 feeGlobal)
        private
        view
        returns (uint64)
    {
        BookLevel storage lvl = fetchLevel(poolIdx, lvlTick);
        return lvlTick <= currentTick ? lvl.feeOdometer_ : feeGlobal - lvl.feeOdometer_;
    }
}

/* @title LP conduit interface
 * @notice Standard interface for contracts that accept and manage LP positions on behalf
 *         of end users. Typical example would be an ERC20 tracker for LP tokens. */
interface ICrocLpConduit {
    /* @notice Called anytime a user mints liquidity against the conduit instance. To 
     *         utilize the user would call a mint operation on the dex with the address
     *         of the LP conduit they want to use. This method will be called to notify
     *         conduit contract (e.g. to perform tracking), and the LP position will be
     *         held in the name of the conduit.
     *
     * @param sender The address of the user that owns the newly minted position.
     * @param poolHash The hash (see PoolRegistry.sol) of the AMM pool the liquidity is
     *                 minted on.
     * @param lowerTick The tick index of the lower range (0 if ambient liquidity)
     * @param upperTick The tick index of the upper range (0 if ambient liquidity)
     * @param liq       The amount of liquidity being minted. If ambient liquidity this
     *                  is denominated as ambient seeds. If concentrated this is flat
     *                  sqrt(X*Y) liquidity of the liquidity minted.
     * @param mileage   The accumulated fee mileage (see PositionRegistrar.sol) of the 
     *                  concentrated liquidity at mint time. If ambient, this is zero.
     *
     * @return   Return false if the conduit implementation does not accept the liquidity
     *           deposit. Reverts the transaction. */
    function depositCrocLiq(
        address sender,
        bytes32 poolHash,
        int24 lowerTick,
        int24 upperTick,
        uint128 liq,
        uint64 mileage
    ) external returns (bool);

    function withdrawCrocLiq(
        address sender,
        bytes32 poolHash,
        int24 lowerTick,
        int24 upperTick,
        uint128 liq,
        uint64 mileage
    ) external returns (bool);
}

/* @title Croc conditional oracle interface
 * @notice Defines a generalized interface for checking an arbitrary condition. Used in
 *         an off-chain relayer context. User can gate specific order on a runtime 
 *         condition by calling to the oracle. */
interface ICrocNonceOracle {
    /* @notice Oracle function that tests a condition.
     *
     * @param user The address of the underlying call.
     * @param nonceSalt The salt of the nonce being reset on this call. Implementations
     *                  can either ignore, or use it to check call-specific conditions.
     * @param nonce The new nonce value that will be set for the user at the salt, if the
     *              oracle returns true. Presumably this nonce will open a secondary order
     *              executes some desired action.
     * @param args Arbitrary args supplied to oracle check call.
     *
     * @return True if the condition is met. If false, CrocSwap will revert the 
     *         transaction, and the nonce will not be reset. */
    function checkCrocNonceSet(address user, bytes32 nonceSalt, uint32 nonce, bytes calldata args)
        external
        returns (bool);
}

interface ICrocCondOracle {
    function checkCrocCond(address user, bytes calldata args) external returns (bool);
}

/* @title Agent mask mixin.
 * @notice Maps and manages surplus balances, nonces, and external router approvals
 *         based on the wallet addresses of end-users. */
contract AgentMask is StorageLayout {
    using SafeCast for uint256;

    /* @notice Standard re-entrant gate for an unprivileged order called directly
     *         by the user.
     *
     * @dev    lockHolder_ account is set to msg.sender, and therefore this call will
     *         touch the positions, tokens, and liquidity owned by msg.sender. */
    modifier reEntrantLock() {
        require(lockHolder_ == address(0));
        lockHolder_ = msg.sender;
        _;
        lockHolder_ = address(0);
        resetMsgVal();
    }

    /* @notice Re-entrant gate for privileged protocol authority commands. */
    modifier protocolOnly(bool sudo) {
        require(msg.sender == authority_ && lockHolder_ == address(0));
        lockHolder_ = msg.sender;
        sudoMode_ = sudo;
        _;
        lockHolder_ = address(0);
        sudoMode_ = false;
        resetMsgVal();
    }

    /* @notice Re-entrant gate for an order called by external router on behalf of a
     *         third party client. Requires the user to have previously approved the 
     *         router.
     *
     * @dev    lockHolder_ is set to the client address directly supplied by the caller.
     *         (The client address must always directly approve the msg.sender contract to
     *         act on its behalf.) Therefore this call (if approved) will touch the positions,
     *         tokens, and liquidity owned by client address.
     *
     * @param client The client who's order the router is calling on behalf of.
     * @param callPath  The proxy sidecar callpath the agent is requesting to call on the user's behalf */
    modifier reEntrantApproved(address client, uint16 callPath) {
        stepAgentNonce(client, msg.sender, callPath);
        require(lockHolder_ == address(0));
        lockHolder_ = client;
        _;
        lockHolder_ = address(0);
        resetMsgVal();
    }

    /* @notice Re-entrant gate for a relayer calling an order that was signed off-chain
     *         using the EIP-712 standard.
     *
     * @dev    lockHolder_ is set to the address whose private key signed the ECDSA 
     *         signature. Regardless of which address is msg.sender, all operations inside
     *         this call will touch the positions, tokens, and liquidity owned by the
     *         signing address.  */
    modifier reEntrantAgent(CrocRelayerCall memory call, bytes calldata signature) {
        require(lockHolder_ == address(0));
        lockHolder_ = lockSigner(call, signature);
        _;
        lockHolder_ = address(0);
        resetMsgVal();
    }

    struct CrocRelayerCall {
        uint16 callpath;
        bytes cmd;
        bytes conds;
        bytes tip;
    }

    /* @notice Atomically returns the msg.value of the transaction and marks the funds as
     *         spent. This provides a layer of safety to prevent msg.value from being spent
     *         twice in a single transaction.
     * @dev    For safety msg.value should *never* be accessed in any way outside this function.
     *         This assures that if msg.value is used at one point in the callpath it isn't 
     *         inadvertantly used at another point, because that would trigger a revert. */
    function popMsgVal() internal returns (uint128 msgVal) {
        require(msgValSpent_ == false, "DS");
        msgVal = msg.value.toUint128();
        msgValSpent_ = true;
    }

    /* @dev This should only be called when the top-level contract call is fully out-of-scope.
     *      Otherwise the risk is msg.val could be double spent. */
    function resetMsgVal() private {
        msgValSpent_ = false;
    }

    /* @notice Given the order, evaluation conditionals, and off-chain signature, recovers
     *         the client address if valid or reverts the transactions. */
    function lockSigner(CrocRelayerCall memory call, bytes calldata signature) private returns (address client) {
        client = verifySignature(call, signature);
        checkRelayConditions(client, call.conds);
    }

    /* @notice Verifies that the conditions signed by the user are met at evaluation time,
     *         and if necessary increments the nonce. 
     *
     * @param client The client who's order is being evaluated on behalf of.
     * @param deadline The deadline (in block time) that the order must be evaluated by.
     * @param alive    The live time (in block time) that the order cannot be evaluated
     *                 before.
     * @param salt     A salt to apply when checking the nonce. Allows users to sign
     *                 an arbitrary number of multiple nonce tracks, so they don't have
     *                 to wait for unrelated orders.
     * @param nonce    The replay-attack prevention nonce. Two orders with the same salt
     *                 and nonce cannot be evaluated (unless the user explicitly resets
     *                 the nonce). A nonce cannot be evaluated until prior orders at
     *                 lower nonces haven been successfully evaluated.
     * @param relayer  Address of the relayer the user requires to evaluate the order.
     *                 Must match either msg.sender or tx.origin. If zero, the order
     *                 does not require a specific relayer. */
    function checkRelayConditions(address client, bytes memory conds) internal {
        (uint48 deadline, uint48 alive, bytes32 salt, uint32 nonce, address relayer) =
            abi.decode(conds, (uint48, uint48, bytes32, uint32, address));

        require(block.timestamp <= deadline);
        require(block.timestamp >= alive);
        require(relayer == address(0) || relayer == msg.sender || relayer == tx.origin);
        stepNonce(client, salt, nonce);
    }

    /* @notice Verifies the supplied signature matches the EIP-712 compatible data.
     *
     * @dev Note that the ECDSA signature is malleable, because (v, r, s) are unrestricted.
     *      However this is not an issue, because the raw signature itself is not used as an
     *      index or nonce in any form. A malicious attacker *could* change the signature, but
     *      could not change the plaintext checksum being signed. 
     * 
     *      If a malleable signature was submitted, either it would arrive before the honest 
     *      signature, in which case the call parameters would be identical. Or it would arrive after
     *      the honest signature, in which case the call parameter would be rejected becaue it
     *      used an expired nonce. In no state of the world does a malleable signature make a 
     *      replay attack possible. */
    function verifySignature(CrocRelayerCall memory call, bytes calldata signature)
        internal
        view
        returns (address client)
    {
        (uint8 v, bytes32 r, bytes32 s) = abi.decode(signature, (uint8, bytes32, bytes32));
        bytes32 checksum = checksumHash(call);
        client = ecrecover(checksum, v, r, s);
        require(client != address(0));
    }

    /* @notice Calculates the EIP-712 hash to check the signature against. */
    function checksumHash(CrocRelayerCall memory call) private view returns (bytes32) {
        bytes32 hash = contentHash(call);
        return keccak256(abi.encodePacked("\x19\x01", domainHash(), hash));
    }

    bytes32 constant CALL_SIG_HASH = keccak256("CrocRelayerCall(uint8 callpath,bytes cmd,bytes conds,bytes tip)");
    bytes32 constant DOMAIN_SIG_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 constant APP_NAME_HASH = keccak256("CrocSwap");
    bytes32 constant VERSION_HASH = keccak256("1.0");

    /* @notice Calculates the EIP-712 typedStruct hash. */
    function contentHash(CrocRelayerCall memory call) private pure returns (bytes32) {
        return keccak256(
            abi.encode(CALL_SIG_HASH, call.callpath, keccak256(call.cmd), keccak256(call.conds), keccak256(call.tip))
        );
    }

    /* @notice Calculates the EIP-712 domain hash. */
    function domainHash() private view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_SIG_HASH, APP_NAME_HASH, VERSION_HASH, block.chainid, address(this)));
    }

    /* @notice Returns the payer and receiver of any settlement collateral flows.
     * @return debit The address that will be paying any debits to the pool.
     * @return credit The address that will receive any credits from the pool. */
    function agentsSettle() internal view returns (address debit, address credit) {
        (debit, credit) = (lockHolder_, lockHolder_);
    }

    /* @notice Approves an external router or agent to act on a user's behalf.
     * @param router The address of the external agent.
     * @param nCalls The number of calls the external router is authorized to make. Set
     *               to uint32.max for unlimited.
     * @param callPath The specific proxy sidecar callpath that the router is approved for */
    function approveAgent(address router, uint32 nCalls, uint16 callPath) internal {
        bytes32 key = agentKey(lockHolder_, router, callPath);
        UserBalance storage bal = userBals_[key];
        bal.agentCallsLeft_ = nCalls;
    }

    /* @notice Sets the nonce index related to EIP-712 off-chain calls. 
     * @param nonceSalt The nonce system is multi-dimensional, which allows relayers to
     *                  pass along arbitrary ordered messages when they come from 
     *                  unrelated streams. This value corresponds to the specific nonce
     *                  dimension.
     * @param nonce The nonce index value the nonce will be reset to. */
    function resetNonce(bytes32 nonceSalt, uint32 nonce) internal {
        UserBalance storage bal = userBals_[nonceKey(lockHolder_, nonceSalt)];
        require(nonce >= bal.nonce_, "NI");
        bal.nonce_ = nonce;
    }

    /* @notice Same as resetNonce but conditions on the successful call return to an 
     *         external oracle. Useful for certain times that a user wants to pre-sign
     *         a transaction, but not let it be executable unless an arbitrary condition
     *         is met. 
     * @param nonceSalt The nonce system is multi-dimensional, which allows relayers to
     *                  pass along arbitrary ordered messages when they come from 
     *                  unrelated streams. This value corresponds to the specific nonce
     *                  dimension.
     * @param nonce The nonce index value the nonce will be reset to.
     * @param oracle The address of the external oracle (must conform to ICrocNonceOracle
     *               interface.
     * @param args Arbitrary calldata passed to the oracle condition call. */
    function resetNonceCond(bytes32 salt, uint32 nonce, address oracle, bytes memory args) internal {
        bool canProceed = ICrocNonceOracle(oracle).checkCrocNonceSet(lockHolder_, salt, nonce, args);
        require(canProceed, "ON");
        resetNonce(salt, nonce);
    }

    /* @notice Flat call that checks an external oracle and reverts the transaction if the
     *         oracle call fails. Useful in a multicall context, where we want to pre-
     *         condition on some external requirement.
     * @param oracle The address of the external oracle (must conform to ICrocCondOracle
     *               interface.
     * @param args Arbitrary calldata passed to the oracle condition call. */
    function checkGateOracle(address oracle, bytes memory args) internal {
        bool canProceed = ICrocCondOracle(oracle).checkCrocCond(lockHolder_, args);
        require(canProceed, "OG");
    }

    /* @notice Compare-and-swap the nCalls on a single external agent call. Checks that
     *         the agent is authorized to perform another call, and if so decrements the
     *         number of remaining calls.
     * @param client The client the agent is making the call on behalf of.
     * @param agent The address of the external agent making the call.
     * @param callPath The proxy sidecar the call is being made on. */
    function stepAgentNonce(address client, address agent, uint16 callPath) internal {
        UserBalance storage bal = userBals_[agentKey(client, agent, callPath)];
        if (bal.agentCallsLeft_ < type(uint32).max) {
            require(bal.agentCallsLeft_ > 0);
            --bal.agentCallsLeft_;
        }
    }

    /* @notice Compare-and-swap the nonce on a single EIP-712 signed transaction. Checks
     *         that the nonce matches the current nonce for the user/salt, and atomically
     *         increments the nonce.
     * @param client The client the agent is making the call on behalf of.
     * @param salt The multidimensional nonce dimension the call is being applied to.
     * @param nonce The nonce the EIP-712 message is signed for. This must match the 
     *              current nonce or the transaction will fail. */
    function stepNonce(address client, bytes32 nonceSalt, uint32 nonce) internal {
        UserBalance storage bal = userBals_[nonceKey(client, nonceSalt)];
        require(bal.nonce_ == nonce);
        ++bal.nonce_;
    }

    /* @notice Called within the context of an EIP-712 transaction, where the underlying
     *         client pays the relayer for having mined the transaction. (If the cmd byte
     *         data is empty, no tip is paid).
     *
     * @dev Thie call will always occur at the *end* of a transaction. So the user must 
     *      have sufficient balance in their surplus collateral to cover the tip by the
     *      completion of the transaction.
     *
     * @param token The token the tip is being paid in. This will always be paid from the
     *              user's surplus collateral balance.
     * @param tip The amount the user is paying in tip. If protocol fee is turned on this
     *            is the *total* amount paid. The relayer will receive this less protocol
     *            fee. Tip can also be set to uint128.max, and will pay the full amount
     *            of the client's surplus collateral balance.
     * @param recv The receiver of the tip. This will always be paid to this account's
     *             surplus collateral balance. Also supports generic magic values for 
     *             generic relayer payment:
     *                 0x100 - Paid to the msg.sender, regardless of who made the dex call
     *                 0x200 - Paid to the tx.origin, regardless of who sent tx. */
    function tipRelayer(bytes memory tipCmd) internal {
        if (tipCmd.length == 0) return;

        (address token, uint128 tip, address recv) = abi.decode(tipCmd, (address, uint128, address));

        recv = maskTipRecv(recv);
        bytes32 fromKey = tokenKey(lockHolder_, token);
        bytes32 toKey = tokenKey(recv, token);

        if (tip == type(uint128).max) {
            tip = userBals_[fromKey].surplusCollateral_;
        }
        require(userBals_[fromKey].surplusCollateral_ >= tip);

        uint128 protoFee = tip * relayerTakeRate_ / 256;
        uint128 relayerTip = tip - protoFee;

        userBals_[fromKey].surplusCollateral_ -= tip;
        userBals_[toKey].surplusCollateral_ += relayerTip;
        if (protoFee > 0) {
            feesAccum_[token] += protoFee;
        }
    }

    address constant MAGIC_SENDER_TIP = address(256);
    address constant MAGIC_ORIGIN_TIP = address(512);

    /* @notice Converts the user's tip recv argument to the actual address to be paid.
     *         In practice this means that the magic values for msg.sender and tx.origin
     *         are converted to those value's actual address for the transaction. */
    function maskTipRecv(address recv) private view returns (address) {
        if (recv == MAGIC_SENDER_TIP) {
            recv = msg.sender;
        } else if (recv == MAGIC_ORIGIN_TIP) {
            recv = tx.origin;
        }
        return recv;
    }

    /* @notice Given a user address and a salt returns a new virtualized user address. 
     *         Useful when we want multiple synthetic accounts tied to a single address.*/
    function virtualizeUser(address client, uint256 salt) internal pure returns (address) {
        if (salt == 0) return client;
        else return PoolSpecs.virtualizeAddress(client, salt);
    }

    /* @notice Returns the user balance key given a user account an an inner salt. */
    function nonceKey(address user, bytes32 innerKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(user, innerKey));
    }

    /* @notice Returns a token balance key given a user and token address. */
    function tokenKey(address user, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(user, token));
    }

    /* @notice Returns a token balance key given a user, token and an arbitrary salt. */
    function tokenKey(address user, address token, uint256 salt) internal pure returns (bytes32) {
        return tokenKey(user, PoolSpecs.virtualizeAddress(token, salt));
    }

    /* @notice Returns an agent key given a user, an agent address and a specific
     *         call path. */
    function agentKey(address user, address agent, uint16 callPath) internal pure returns (bytes32) {
        return keccak256(abi.encode(user, agent, callPath));
    }
}

/* @title Knockout Counter
 * @notice Manages the knockout liquidity pivots and positions. Responsible for minting
 *         burning, knocking out, and claiming knockout liquidity, and adjusting bump
 *         points in LevelBook accordingly. *Not* responsible for managing liquidity on 
 *         the curve or debiting/creditiing collateral. Knockout liquidity positions 
 *         should be separately managed from ordinary liquidity, but knockout liquidity 
 *         should be aggregated with AMM/bump point liquidity. */
contract KnockoutCounter is LevelBook, PoolRegistry, AgentMask {
    using SafeCast for uint128;
    using LiquidityMath for uint128;
    using LiquidityMath for uint96;
    using LiquidityMath for uint64;
    using KnockoutLiq for KnockoutLiq.KnockoutMerkle;
    using KnockoutLiq for KnockoutLiq.KnockoutPivot;
    using KnockoutLiq for KnockoutLiq.KnockoutPosLoc;

    /* @notice Emitted at any point a pivot is knocked out. User can use the history
     *         of these logs to reconstructo the Merkle history necessary to claim
     *         their fees. */
    event CrocKnockoutCross(
        bytes32 indexed pool, int24 indexed tick, bool isBid, uint32 pivotTime, uint64 feeMileage, uint160 commitEntropy
    );

    /* @notice Called when a given knockout pivot is crossed. Performs the book-keeping
     *         related to reseting the pivot object and committing the Merkle history.
     *         Does *not* adjust the liquidity on the bump point or curve, caller is
     *         responsible for that upstream.
     * 
     * @dev This function must only be called *after* the AMM curve has crossed the
     *      tick and fee odometer on the tick has been updated to reflect the update.
     *
     * @param pool The hash index of the AMM pool.
     * @param isBid If true, indicates that it's a bid pivot being knocked out (i.e.
     *              that price is moving down through the pivot)
     * @param tick The tick index of the knockout pivot.
     * @param feeMileage The in range fee mileage at the point the pivot was crossed. */
    function crossKnockout(bytes32 pool, bool isBid, int24 tick, uint64 feeGlobal) internal {
        bytes32 lvlKey = KnockoutLiq.encodePivotKey(pool, isBid, tick);
        KnockoutLiq.KnockoutPivot storage pivot = knockoutPivots_[lvlKey];
        KnockoutLiq.KnockoutMerkle storage merkle = knockoutMerkles_[lvlKey];

        unmarkPivot(pool, isBid, tick);
        uint64 feeRange = knockoutRangeLiq(pool, pivot, isBid, tick, feeGlobal);

        merkle.commitKnockout(pivot, feeRange);
        emit CrocKnockoutCross(
            pool, tick, isBid, merkle.pivotTime_, merkle.feeMileage_, KnockoutLiq.commitEntropySalt()
        );
        pivot.deletePivot(); // Nice little SSTORE refund for the swapper
    }

    /* @notice Removes the liquidity at the AMM curve's bump points as part of a pivot
     *         being knocked out by a level cross. */
    function knockoutRangeLiq(
        bytes32 pool,
        KnockoutLiq.KnockoutPivot memory pivot,
        bool isBid,
        int24 tick,
        uint64 feeGlobal
    ) private returns (uint64 feeRange) {
        // Unchecked because min/max tick are well within uint16 of int24 bounds
        unchecked {
            int24 offset = int24(uint24(pivot.rangeTicks_));
            int24 priceTick = isBid ? tick - 1 : tick;
            int24 lowerTick = isBid ? tick : tick - offset;
            int24 upperTick = !isBid ? tick : tick + offset;
            feeRange = removeBookLiq(pool, priceTick, lowerTick, upperTick, pivot.lots_, feeGlobal);
        }
    }

    /* @notice Mints a new knockout liquidity position (or adds liquidity to a pre-
     *         existing position.
     *
     * @param pool The cursor for the pool knockout liquidity is being added to.
     * @param knockoutBits The current knockout parameter flags in the pool's settings.
     * @param curveTick The 24-bit tick index of the current curve price in the pool
     * @param feeGlobal The global cumulative concentrated liquidity fee mileage for
     *                  the curve at mint time.
     * @param loc       The position on the curve the knockout liquidity is being added
     *                  to. (See comments for struct for full explanation of fields)
     * @param lots    The amount of liquidity lots (in lots of 1024-units of 
     *                sqrt(X*Y) liquidity) being added to the knockout position. 
     *
     * @return pivotTime  The time tranche of the pivot the liquidity was added to.
     * @return newPivot If true indicates that this is the first active liquidity at the
     *                  pivot. */
    function addKnockoutLiq(
        bytes32 pool,
        uint8 knockoutBits,
        int24 curveTick,
        uint64 feeGlobal,
        KnockoutLiq.KnockoutPosLoc memory loc,
        uint96 lots
    ) internal returns (uint32 pivotTime, bool newPivot) {
        (pivotTime, newPivot) = injectPivot(pool, knockoutBits, loc, lots, curveTick);
        uint64 feeRange = addBookLiq(pool, curveTick, loc.lowerTick_, loc.upperTick_, lots, feeGlobal);
        if (newPivot) {
            markPivot(pool, loc);
        }
        insertPosition(pool, loc, lots, feeRange, pivotTime);
    }

    /* @notice Burns pre-exisitng knockout liquidity, but only if the liqudity is still
     *         alive. (Knocked out positions should use claimKnockout() instead).
     *
     * @param pool The cursor for the pool knockout liquidity is being added to.
     * @param curveTick The 24-bit tick index of the current curve price in the pool
     * @param feeGlobal The global cumulative concentrated liquidity fee mileage for
     *                  the curve at mint time.
     * @param loc       The position on the curve the knockout liquidity is being claimed
     *                  from. (See comments for struct for full explanation of fields)
     *                  to. (See comments for struct for full explanation of fields)
     * @param lots    The amount of liquidity lots (in lots of 1024-units of 
     *                sqrt(X*Y) liquidity) being added to the knockout position. 
     *
     * @return killsPivot If true indicates that removing this liquidity means the pivot
     *                    has no remaining liquidity.
     * @return pivotTime The tranche time of the underlying pivot the liquidity was 
     *                   removed from.
     * @return rewards  The concentrated liquidity rewards accumulated to the 
     *                  position. */
    function rmKnockoutLiq(
        bytes32 pool,
        int24 curveTick,
        uint64 feeGlobal,
        KnockoutLiq.KnockoutPosLoc memory loc,
        uint96 lots
    ) internal returns (bool killsPivot, uint32 pivotTime, uint64 rewards) {
        (pivotTime, killsPivot) = recallPivot(pool, loc, lots);
        if (killsPivot) unmarkPivot(pool, loc);

        uint64 feeRange = removeBookLiq(pool, curveTick, loc.lowerTick_, loc.upperTick_, lots, feeGlobal);
        rewards = removePosition(pool, loc, lots, feeRange, pivotTime);
    }

    /* @notice Marks the tick level as containing a knockout pivot.
     * @dev This is done by switching on the least significant bit in the bump point.
     *      Based on the spec of liquidity lots (see LiquidityMath.sol), this least 
     *      significant bit should *not* be treated as actual liquidity, but rather just
     *      an unrelated flag indicating that the level has a corresponding active 
     *      knockout pivot. */
    function markPivot(bytes32 pool, KnockoutLiq.KnockoutPosLoc memory loc) private {
        if (loc.isBid_) {
            BookLevel storage lvl = fetchLevel(pool, loc.lowerTick_);
            lvl.bidLots_ = lvl.bidLots_ | uint96(0x1);
        } else {
            BookLevel storage lvl = fetchLevel(pool, loc.upperTick_);
            lvl.askLots_ = lvl.askLots_ | uint96(0x1);
        }
    }

    /* @notice Removes the mark on the book level related to the presence of knockout 
     *         liquidity. */
    function unmarkPivot(bytes32 pool, KnockoutLiq.KnockoutPosLoc memory loc) private {
        if (loc.isBid_) {
            unmarkPivot(pool, true, loc.lowerTick_);
        } else {
            unmarkPivot(pool, false, loc.upperTick_);
        }
    }

    /* @notice Removes the mark on the book level related to the presence of knockout 
     *         liquidity. */
    function unmarkPivot(bytes32 pool, bool isBid, int24 tick) private {
        BookLevel storage lvl = fetchLevel(pool, tick);
        if (isBid) {
            lvl.bidLots_ = lvl.bidLots_ & ~uint96(0x1);
        } else {
            lvl.askLots_ = lvl.askLots_ & ~uint96(0x1);
        }
    }

    /* @notice Claims the collateral and rewards for a position that has been fully 
     *         knocked out. (I.e. is no longer active because knockout tick was crossed)
     * 
     * @param pool The cursor for the pool knockout liquidity is being added to.
     * @param loc       The position on the curve the knockout liquidity is being claimed
     *                  from. (See comments for struct for full explanation of fields)
     * @param merkleRoot The root of the Merkle proof to recover the accumulted fees.
     * @param merkleProof The user-supplied proof for the accumulated fees earned by
     *                    the knockout pivot. (Transaction will revert if proof is bad)
     *
     * @return lots    The liquidity (in 1024-unit lots) claimable by the underlying 
     *                 position. Note that this liquidity should be converted to 
     *                 collateral at the knockout price *not* the current curve price).
     * @return rewards The in-range concentrated liquidity rewards earned by the position.
     */
    function claimPostKnockout(
        bytes32 pool,
        KnockoutLiq.KnockoutPosLoc memory loc,
        uint160 merkleRoot,
        uint256[] memory merkleProof
    ) internal returns (uint96 lots, uint64 rewards) {
        (uint32 pivotTime, uint64 feeSnap) = proveKnockout(pool, loc, merkleRoot, merkleProof);
        (lots, rewards) = claimPosition(pool, loc, feeSnap, pivotTime);
    }

    /* @notice Like claimKnockout(), but avoids the need for Merkle proof altogether.
     *         This means the underlying collateral is recoverable, but user renounces
     *         all claims to the accumulated rewards.
     *
     * @dev    This might be used when the calldata cost of the Merkle proof exceeds
     *         the value of the accumulated rewards.
     *
     * @param pool The cursor for the pool knockout liquidity is being added to.
     * @param loc       The position on the curve the knockout liquidity is being claimed
     *                  from. (See comments for struct for full explanation of fields)
     * @param pivotTime The pivot trache the position was minted at. User-supplied value
     *                  must match the position's stored value. Used to verify that the
     *                  tranche is no longer active (otherwise use burnKnockout())
     * @return lots    The liquidity (in 1024-unit lots) claimable by the underlying 
     *                 position. Note that this liquidity should be converted to 
     *                 collateral at the knockout price *not* the current curve price).*/
    function recoverPostKnockout(bytes32 pool, KnockoutLiq.KnockoutPosLoc memory loc, uint32 pivotTime)
        internal
        returns (uint96 lots)
    {
        confirmPivotDead(pool, loc, pivotTime);
        (lots,) = claimPosition(pool, loc, 0, pivotTime);
    }

    /* @notice Inserts the tracking data for the individual position being minted.
     * @param pool The hash of the pool the liquidity applies to.
     * @param loc The context/location data of the knockout liquidity position.
     * @param lots The amount of liquidity minted to the position.
     * @param feeRange The cumulative fee mileage for the concentrated liquidity range
     *                 at current mint time.
     * @param pivotTime The time corresponding to the underlying pivot creation. */
    function insertPosition(
        bytes32 pool,
        KnockoutLiq.KnockoutPosLoc memory loc,
        uint96 lots,
        uint64 feeRange,
        uint32 pivotTime
    ) private {
        bytes32 posKey = loc.encodePosKey(pool, lockHolder_, pivotTime);
        KnockoutLiq.KnockoutPos storage pos = knockoutPos_[posKey];

        uint64 mileage = feeRange.blendMileage(lots, pos.feeMileage_, pos.lots_);

        pos.lots_ += lots;
        pos.feeMileage_ = mileage;
        pos.timestamp_ = SafeCast.timeUint32();
    }

    /* @notice Removes the tracking data for an individual knockout liquidity position.
     * @dev Should only be called when the underlying knockout pivot *is still active*
     * @param pool The hash of the pool the liquidity applies to.
     * @param loc The context/location data of the knockout liquidity position.
     * @param lots The amount of liquidity burned from the position.
     * @param feeRange The cumulative fee mileage for the concentrated liquidity range
     *                 at current mint time.
     * @param pivotTime The time corresponding to the underlying pivot creation.
     * @return feeRewards The accumulated fee rewards rate on the position. */
    function removePosition(
        bytes32 pool,
        KnockoutLiq.KnockoutPosLoc memory loc,
        uint96 lots,
        uint64 feeRange,
        uint32 pivotTime
    ) private returns (uint64 feeRewards) {
        bytes32 posKey = loc.encodePosKey(pool, lockHolder_, pivotTime);
        KnockoutLiq.KnockoutPos storage pos = knockoutPos_[posKey];

        feeRewards = feeRange.deltaRewardsRate(pos.feeMileage_);
        assertJitSafe(pos.timestamp_, pool);
        require(lots <= pos.lots_, "KB");

        if (lots == pos.lots_) {
            // Get SSTORE refund on full burn
            pos.lots_ = 0;
            pos.feeMileage_ = 0;
            pos.timestamp_ = 0;
        } else {
            pos.lots_ -= lots;
        }
    }

    /* @notice Removes the tracking data for an individual knockout liquidity position 
     *         that's being claimed post knockout. 
     * @dev Should only be called *after* the underlying pivot is knocked out.
     * @param pool The hash of the pool the liquidity applies to.
     * @param loc The context/location data of the knockout liquidity position.
     * @param feeRange The cumulative fee mileage for the concentrated liquidity range
     *                 at current mint time.
     * @param pivotTime The time corresponding to the underlying pivot creation.
     * @return lots The amount of liquidity lots in the underlying position. 
     * @return feeRewards The accumulated fee rewards rate on the position. */
    function claimPosition(bytes32 pool, KnockoutLiq.KnockoutPosLoc memory loc, uint64 feeRange, uint32 pivotTime)
        private
        returns (uint96 lots, uint64 feeRewards)
    {
        bytes32 posKey = loc.encodePosKey(pool, lockHolder_, pivotTime);
        KnockoutLiq.KnockoutPos storage pos = knockoutPos_[posKey];

        lots = pos.lots_;
        if (feeRange > 0) {
            feeRewards = feeRange - pos.feeMileage_;
        }

        // Get SSTORE refund on full burn
        pos.lots_ = 0;
        pos.feeMileage_ = 0;
        pos.timestamp_ = 0;
    }

    /* @notice Creates a new pivot or updates a previous pivot for newly minted knockout
     *         liquidity.
     * @param pool The pool the knockout liquidity applies to.
     * @param loc The context/location of the newly minted knockout liquidity.
     * @param liq The amount of liquidity being minted to the position.
     * @param curveTick The tick index of the current price in the curve.
     * @return bookLiq The amount of liquidity that must be contributed to the range in
     *                 the book. This amount could possibly be different than liq, so 
     *                 it's very important that this value is used to adjust the curve 
     *                 and collect collateral.
     * @return pivotTime The time tranche of the pivot the liquidity is added to. Either
     *                   the current time if liquidity creates a new pivot, or the 
     *                   timestamp of when the previous tranche was created. */
    function injectPivot(
        bytes32 pool,
        uint8 knockoutBits,
        KnockoutLiq.KnockoutPosLoc memory loc,
        uint96 lots,
        int24 curveTick
    ) private returns (uint32 pivotTime, bool newPivot) {
        bytes32 lvlKey = loc.encodePivotKey(pool);
        KnockoutLiq.KnockoutPivot storage pivot = knockoutPivots_[lvlKey];
        newPivot = (pivot.lots_ == 0);

        // If mint represents the first position in a new pivot perorm book keeping
        // related to setting the time tranch, warming up the Merkle slot, and verifying
        // that the pivot position is valid relative to the pool's current parameters.
        if (newPivot) {
            pivotTime = SafeCast.timeUint32();
            freshenMerkle(knockoutMerkles_[lvlKey]);
            loc.assertValidPos(curveTick, knockoutBits);

            // Should optimize to a single SSTORE call.
            pivot.lots_ = lots;
            pivot.pivotTime_ = pivotTime;
            pivot.rangeTicks_ = loc.tickRange();
        } else {
            pivot.lots_ += lots;
            pivotTime = pivot.pivotTime_;
            require(pivot.rangeTicks_ == loc.tickRange(), "KR");
        }
    }

    /* @notice Called to withdraw liquidity from an open knockout pivot. (If pivot was
     *         already knocked out, do not use this function.
     * @param pool The pool the knockout liquidity applies to.
     * @param loc The context/location of the newly minted knockout liquidity.
     * @param liq The amount of liquidity being minted to the position.
     * @return bookLiq The amount of liquidity that shoudl be removed from the book. 
     *                 This amount could possibly be different than liq, so it's very 
     *                 important that this value is used to adjust the AMM curve. 
     * @return pivotTime The tranche timestamp of the current knockout pivot. */
    function recallPivot(bytes32 pool, KnockoutLiq.KnockoutPosLoc memory loc, uint96 lots)
        private
        returns (uint32 pivotTime, bool killsPivot)
    {
        bytes32 lvlKey = KnockoutLiq.encodePivotKey(pool, loc.isBid_, loc.knockoutTick());
        KnockoutLiq.KnockoutPivot storage pivot = knockoutPivots_[lvlKey];
        pivotTime = pivot.pivotTime_;
        require(lots <= pivot.lots_, "KB");
        killsPivot = (lots == pivot.lots_);

        if (killsPivot) {
            // Get the SSTORE refund when completely burning the level
            pivot.lots_ = 0;
            pivot.pivotTime_ = 0;
            pivot.rangeTicks_ = 0;
        } else {
            pivot.lots_ -= lots;
        }
    }

    /* @notice Call on the corresponding Merkle root when creating a new pivot at a 
     *         tick/time tranche. */
    function freshenMerkle(KnockoutLiq.KnockoutMerkle storage merkle) private {
        // Knockout tranches are uniquely identified by block times. There is a
        // rare corner case where multiple knockouts are created, crossed and
        // created again at the same tick all within the same block/time.
        require(merkle.pivotTime_ != SafeCast.timeUint32(), "KT");

        // Warm up the slot so that the SSTORE fresh is paid by the LP, not
        // the swapper. This means all Merkle histories begin with a root of 1
        if (merkle.merkleRoot_ == 0) {
            merkle.merkleRoot_ = 1;
        }
    }

    /* @notice Asserts that a given pivot tranche being claimed as knocked out, was
     *         in fact knocked out. Used when the user doesn't have or doesn't want to
     *         present a Merkle proof.
     *
     * @dev    Relies on two guarantees. 1) base Merkle time is always increasing, 
     *         because pivots are created, and therefore knocked out, in monotonically
     *         increasing time order. 2) Tranches will never be created at the same time-
     *         stamp as the most recent Merkle commitment. Therefore a pivot tranche
     *         has been knocked out if and only if the most recent Merkle commitment has
     *         an equal of greater timestamp. */
    function confirmPivotDead(bytes32 pool, KnockoutLiq.KnockoutPosLoc memory loc, uint32 pivotTime) private view {
        bytes32 lvlKey = KnockoutLiq.encodePivotKey(pool, loc.isBid_, loc.knockoutTick());
        KnockoutLiq.KnockoutMerkle storage merkle = knockoutMerkles_[lvlKey];
        require(merkle.pivotTime_ >= pivotTime, "KA");
    }

    /* @notice Verifies the user-supplied Merkle proof. (See proveHistory() in 
     *         KnockoutLiq library). If proof is wrong, transaction will revert.
     *
     * @return pivotTime The pivot time from the verified proof. Caller is responsible
     *                   for making sure this matches the pivotTime in the position
     *                   being claimed.
     * @return feeSnap The in-range fee mileage at Merkle commitment time, i.e. when the
     *                 pivot was knocked out. */
    function proveKnockout(bytes32 pool, KnockoutLiq.KnockoutPosLoc memory loc, uint160 root, uint256[] memory proof)
        private
        view
        returns (uint32 pivotTime, uint64 feeSnap)
    {
        bytes32 lvlKey = KnockoutLiq.encodePivotKey(pool, loc.isBid_, loc.knockoutTick());
        KnockoutLiq.KnockoutMerkle storage merkle = knockoutMerkles_[lvlKey];
        (pivotTime, feeSnap) = merkle.proveHistory(root, proof);
    }
}

/* @title Proxy Caller
 * @notice Because of the Ethereum contract limit, much of the CrocSwap code is pushed
 *         into sidecar proxy contracts, which is involed with DELEGATECALLs. The code
 *         moved to these sidecars is less gas critical than the code in the core contract. 
 *         This provides a facility for invoking proxy conjtracts in a consistent way by
*          setting up the DELEGATECALLs in a standard and safe manner. */
contract ProxyCaller is StorageLayout {
    using CurveCache for CurveCache.Cache;
    using CurveMath for CurveMath.CurveState;
    using Chaining for Chaining.PairFlow;

    /* @notice Passes through the protocolCmd call to a sidecar proxy. */
    function callProtocolCmd(uint16 proxyIdx, bytes calldata input) internal returns (bytes memory) {
        assertProxy(proxyIdx);
        (bool success, bytes memory output) =
            proxyPaths_[proxyIdx].delegatecall(abi.encodeWithSignature("protocolCmd(bytes)", input));
        return verifyCallResult(success, output);
    }

    /* @notice Passes through the userCmd call to a sidecar proxy. */
    function callUserCmd(uint16 proxyIdx, bytes calldata input) internal returns (bytes memory) {
        assertProxy(proxyIdx);
        (bool success, bytes memory output) =
            proxyPaths_[proxyIdx].delegatecall(abi.encodeWithSignature("userCmd(bytes)", input));
        return verifyCallResult(success, output);
    }

    function callUserCmdMem(uint16 proxyIdx, bytes memory input) internal returns (bytes memory) {
        assertProxy(proxyIdx);
        (bool success, bytes memory output) =
            proxyPaths_[proxyIdx].delegatecall(abi.encodeWithSignature("userCmd(bytes)", input));
        return verifyCallResult(success, output);
    }

    function assertProxy(uint16 proxyIdx) private view {
        require(proxyPaths_[proxyIdx] != address(0));
        require(!inSafeMode_ || proxyIdx == CrocSlots.SAFE_MODE_PROXY_PATH || proxyIdx == CrocSlots.BOOT_PROXY_IDX);
    }

    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        // On success pass through the return data
        if (success) {
            return returndata;
        } else if (returndata.length > 0) {
            // If DELEGATECALL failed bubble up the error message
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            // If failed with no  error, then bubble up the empty revert
            revert();
        }
    }

    /* @notice Invokes mintAmbient() call in MicroPaths sidecar and relays the result. */
    function callMintAmbient(CurveCache.Cache memory curve, uint128 liq, bytes32 poolHash)
        internal
        returns (int128 basePaid, int128 quotePaid)
    {
        (bool success, bytes memory output) = proxyPaths_[CrocSlots.MICRO_PROXY_IDX].delegatecall(
            abi.encodeWithSignature(
                "mintAmbient(uint128,uint128,uint128,uint64,uint64,uint128,bytes32)",
                curve.curve_.priceRoot_,
                curve.curve_.ambientSeeds_,
                curve.curve_.concLiq_,
                curve.curve_.seedDeflator_,
                curve.curve_.concGrowth_,
                liq,
                poolHash
            )
        );
        require(success);

        (basePaid, quotePaid, curve.curve_.ambientSeeds_) = abi.decode(output, (int128, int128, uint128));
    }

    /* @notice Invokes burnAmbient() call in MicroPaths sidecar and relays the result. */
    function callBurnAmbient(CurveCache.Cache memory curve, uint128 liq, bytes32 poolHash)
        internal
        returns (int128 basePaid, int128 quotePaid)
    {
        (bool success, bytes memory output) = proxyPaths_[CrocSlots.MICRO_PROXY_IDX].delegatecall(
            abi.encodeWithSignature(
                "burnAmbient(uint128,uint128,uint128,uint64,uint64,uint128,bytes32)",
                curve.curve_.priceRoot_,
                curve.curve_.ambientSeeds_,
                curve.curve_.concLiq_,
                curve.curve_.seedDeflator_,
                curve.curve_.concGrowth_,
                liq,
                poolHash
            )
        );
        require(success);

        (basePaid, quotePaid, curve.curve_.ambientSeeds_) = abi.decode(output, (int128, int128, uint128));
    }

    /* @notice Invokes mintRange() call in MicroPaths sidecar and relays the result. */
    function callMintRange(CurveCache.Cache memory curve, int24 bidTick, int24 askTick, uint128 liq, bytes32 poolHash)
        internal
        returns (int128 basePaid, int128 quotePaid)
    {
        (bool success, bytes memory output) = proxyPaths_[CrocSlots.MICRO_PROXY_IDX].delegatecall(
            abi.encodeWithSignature(
                "mintRange(uint128,int24,uint128,uint128,uint64,uint64,int24,int24,uint128,bytes32)",
                curve.curve_.priceRoot_,
                curve.pullPriceTick(),
                curve.curve_.ambientSeeds_,
                curve.curve_.concLiq_,
                curve.curve_.seedDeflator_,
                curve.curve_.concGrowth_,
                bidTick,
                askTick,
                liq,
                poolHash
            )
        );
        require(success);

        (basePaid, quotePaid, curve.curve_.ambientSeeds_, curve.curve_.concLiq_) =
            abi.decode(output, (int128, int128, uint128, uint128));
    }

    /* @notice Invokes burnRange() call in MicroPaths sidecar and relays the result. */
    function callBurnRange(CurveCache.Cache memory curve, int24 bidTick, int24 askTick, uint128 liq, bytes32 poolHash)
        internal
        returns (int128 basePaid, int128 quotePaid)
    {
        (bool success, bytes memory output) = proxyPaths_[CrocSlots.MICRO_PROXY_IDX].delegatecall(
            abi.encodeWithSignature(
                "burnRange(uint128,int24,uint128,uint128,uint64,uint64,int24,int24,uint128,bytes32)",
                curve.curve_.priceRoot_,
                curve.pullPriceTick(),
                curve.curve_.ambientSeeds_,
                curve.curve_.concLiq_,
                curve.curve_.seedDeflator_,
                curve.curve_.concGrowth_,
                bidTick,
                askTick,
                liq,
                poolHash
            )
        );
        require(success);

        (basePaid, quotePaid, curve.curve_.ambientSeeds_, curve.curve_.concLiq_) =
            abi.decode(output, (int128, int128, uint128, uint128));
    }

    /* @notice Invokes sweepSwap() call in MicroPaths sidecar and relays the result. */
    function callSwap(
        Chaining.PairFlow memory accum,
        CurveCache.Cache memory curve,
        Directives.SwapDirective memory swap,
        PoolSpecs.PoolCursor memory pool
    ) internal {
        (bool success, bytes memory output) = proxyPaths_[CrocSlots.MICRO_PROXY_IDX].delegatecall(
            abi.encodeWithSignature(
                "sweepSwap((uint128,uint128,uint128,uint64,uint64),int24,(bool,bool,uint8,uint128,uint128),((uint8,uint16,uint8,uint16,uint8,uint8,uint8),bytes32,address))",
                curve.curve_,
                curve.pullPriceTick(),
                swap,
                pool
            )
        );
        require(success);

        Chaining.PairFlow memory swapFlow;
        (
            swapFlow,
            curve.curve_.priceRoot_,
            curve.curve_.ambientSeeds_,
            curve.curve_.concLiq_,
            curve.curve_.seedDeflator_,
            curve.curve_.concGrowth_
        ) = abi.decode(output, (Chaining.PairFlow, uint128, uint128, uint128, uint64, uint64));

        // swap() is the only operation that can change curve price, so have to mark
        // the tick cache as dirty.
        curve.dirtyPrice();
        accum.foldFlow(swapFlow);
    }

    function callCrossFlag(bytes32 poolHash, int24 tick, bool isBuy, uint64 feeGlobal)
        internal
        returns (int128 concLiqDelta)
    {
        require(proxyPaths_[CrocSlots.FLAG_CROSS_PROXY_IDX] != address(0));

        (bool success, bytes memory cmd) = proxyPaths_[CrocSlots.FLAG_CROSS_PROXY_IDX].delegatecall(
            abi.encodeWithSignature("crossCurveFlag(bytes32,int24,bool,uint64)", poolHash, tick, isBuy, feeGlobal)
        );
        require(success);

        concLiqDelta = abi.decode(cmd, (int128));
    }
}

/* @title Trade matcher mixin
 * @notice Provides a unified facility for calling the core atomic trade actions
 *         on a pre-loaded liquidity curve:
 *           1) Mint amibent liquidity
 *           2) Mint range liquidity
 *           3) Burn ambient liquidity
 *           4) Burn range liquidity
 *           5) Swap                                                     */
contract TradeMatcher is PositionRegistrar, LiquidityCurve, KnockoutCounter, ProxyCaller {
    using SafeCast for int256;
    using SafeCast for int128;
    using SafeCast for uint256;
    using SafeCast for uint128;
    using TickMath for uint128;
    using LiquidityMath for uint96;
    using LiquidityMath for uint128;
    using PoolSpecs for PoolSpecs.Pool;
    using CurveRoll for CurveMath.CurveState;
    using CurveMath for CurveMath.CurveState;
    using SwapCurve for CurveMath.CurveState;
    using Directives for Directives.ConcentratedDirective;
    using Chaining for Chaining.PairFlow;

    /* @notice Mints ambient liquidity (i.e. liquidity that stays active at every
     *         price point) on to the curve.
     * 
     * @param curve The object representing the pre-loaded liquidity curve. Will be
     *              updated in memory after this call, but it's the caller's 
     *              responsbility to check it back into storage.
     * @param liqAdded The amount of ambient liquidity being minted represented as
     *                 sqrt(X*Y) where X,Y are the collateral reserves in a constant-
     *                 product AMM
     * @param poolHash The hash indexing the pool this liquidity curve applies to.
     * @param lpOwner The address of the ICrocLpConduit the LP position will be 
     *                assigned to. (If zero the user will directly own the LP.)
     *
     * @return baseFlow The amount of base-side token collateral required by this
     *                  operations. Will always be positive indicating, a debit from
     *                  the user to the pool.
     * @return quoteFlow The amount of quote-side token collateral required by thhis
     *                   operation. */
    function mintAmbient(CurveMath.CurveState memory curve, uint128 liqAdded, bytes32 poolHash, address lpOwner)
        internal
        returns (int128 baseFlow, int128 quoteFlow)
    {
        uint128 liqSeeds = mintPosLiq(lpOwner, poolHash, liqAdded, curve.seedDeflator_);
        depositConduit(poolHash, liqSeeds, curve.seedDeflator_, lpOwner);

        (uint128 base, uint128 quote) = liquidityReceivable(curve, liqSeeds);
        (baseFlow, quoteFlow) = signMintFlow(base, quote);
    }

    /* @notice Like mintAmbient(), but the liquidity is permanetely locked into the pool,
     *         and therefore cannot be later burned by the user. */
    function lockAmbient(CurveMath.CurveState memory curve, uint128 liqAdded) internal pure returns (int128, int128) {
        (uint128 base, uint128 quote) = liquidityReceivable(curve, liqAdded);
        return signMintFlow(base, quote);
    }

    /* @notice Burns ambient liquidity from the curve.
     * 
     * @param curve The object representing the pre-loaded liquidity curve. Will be
     *              updated in memory after this call, but it's the caller's 
     *              responsbility to check it back into storage.
     * @param liqAdded The amount of ambient liquidity being minted represented as
     *                 sqrt(X*Y) where X,Y are the collateral reserves in a constant-
     *                 product AMM
     * @param poolHash The hash indexing the pool this liquidity curve applies to.
     *
     * @return baseFlow The amount of base-side token collateral returned by this
     *                  operations. Will always be negative indicating, a credit from
     *                  the pool to the user.
     * @return quoteFlow The amount of quote-side token collateral returned by this
     *                   operation. */
    function burnAmbient(CurveMath.CurveState memory curve, uint128 liqBurned, bytes32 poolHash, address lpOwner)
        internal
        returns (int128, int128)
    {
        uint128 liqSeeds = burnPosLiq(lpOwner, poolHash, liqBurned, curve.seedDeflator_);
        withdrawConduit(poolHash, liqSeeds, curve.seedDeflator_, lpOwner);

        (uint128 base, uint128 quote) = liquidityPayable(curve, liqSeeds);
        return signBurnFlow(base, quote);
    }

    /* @notice Mints concernated liquidity within a range on to the curve.
     * 
     * @param curve The object representing the pre-loaded liquidity curve. Will be
     *              updated in memory after this call, but it's the caller's 
     *              responsbility to check it back into storage.
     * @param prickTick The tick index of the curve's current price.
     * @param lowTick The tick index of the lower boundary of the range order.
     * @param highTick The tick index of the upper boundary of the range order.
     * @param liqAdded The amount of ambient liquidity being minted represented as
     *                 sqrt(X*Y) where X,Y are the collateral reserves in a constant-
     *                 product AMM
     * @param poolHash The hash indexing the pool this liquidity curve applies to.
     * @param lpConduit The address of the ICrocLpConduit the LP position will be 
     *                  assigned to. (If zero the user will directly own the LP.)
     *
     * @return baseFlow The amount of base-side token collateral required by this
     *                  operations. Will always be positive indicating, a debit from
     *                  the user to the pool.
     * @return quoteFlow The amount of quote-side token collateral required by thhis
     *                   operation. */
    function mintRange(
        CurveMath.CurveState memory curve,
        int24 priceTick,
        int24 lowTick,
        int24 highTick,
        uint128 liquidity,
        bytes32 poolHash,
        address lpOwner
    ) internal returns (int128 baseFlow, int128 quoteFlow) {
        uint64 feeMileage =
            addBookLiq(poolHash, priceTick, lowTick, highTick, liquidity.liquidityToLots(), curve.concGrowth_);

        mintPosLiq(lpOwner, poolHash, lowTick, highTick, liquidity, feeMileage);
        depositConduit(poolHash, lowTick, highTick, liquidity, feeMileage, lpOwner);

        (uint128 base, uint128 quote) = liquidityReceivable(curve, liquidity, lowTick, highTick);
        (baseFlow, quoteFlow) = signMintFlow(base, quote);
    }

    /* @notice Burns concernated liquidity within a specific range off of the curve.
     * 
     * @param curve The object representing the pre-loaded liquidity curve. Will be
     *              updated in memory after this call, but it's the caller's 
     *              responsbility to check it back into storage.
     * @param prickTick The tick index of the curve's current price.
     * @param lowTick The tick index of the lower boundary of the range order.
     * @param highTick The tick index of the upper boundary of the range order.
     * @param liqAdded The amount of ambient liquidity being minted represented as
     *                 sqrt(X*Y) where X,Y are the collateral reserves in a constant-
     *                 product AMM
     * @param poolHash The hash indexing the pool this liquidity curve applies to.
     *
     * @return baseFlow The amount of base-side token collateral returned by this
     *                  operations. Will always be negative indicating, a credit from
     *                  the pool to the user.
     * @return quoteFlow The amount of quote-side token collateral returned by this
     *                   operation. */
    function burnRange(
        CurveMath.CurveState memory curve,
        int24 priceTick,
        int24 lowTick,
        int24 highTick,
        uint128 liquidity,
        bytes32 poolHash,
        address lpOwner
    ) internal returns (int128, int128) {
        uint64 feeMileage =
            removeBookLiq(poolHash, priceTick, lowTick, highTick, liquidity.liquidityToLots(), curve.concGrowth_);
        uint64 rewards = burnPosLiq(lpOwner, poolHash, lowTick, highTick, liquidity, feeMileage);
        withdrawConduit(poolHash, lowTick, highTick, liquidity, feeMileage, lpOwner);
        (uint128 base, uint128 quote) = liquidityPayable(curve, liquidity, rewards, lowTick, highTick);
        return signBurnFlow(base, quote);
    }

    /* @notice Dispatches the call to the ICrocLpConduit with the ambient liquidity 
     *         LP position that was minted. */
    function depositConduit(bytes32 poolHash, uint128 liqSeeds, uint64 deflator, address lpConduit) private {
        // Equivalent to calling concentrated liquidity deposit with lowTick=0 and highTick=0
        // Since a true range order can never have a width of zero, the receiving deposit
        // contract should recognize these values as always representing ambient liquidity
        int24 NA_LOW_TICK = 0;
        int24 NA_HIGH_TICK = 0;
        depositConduit(poolHash, NA_LOW_TICK, NA_HIGH_TICK, liqSeeds, deflator, lpConduit);
    }

    /* @notice Dispatches the call to the ICrocLpConduit with the concentrated liquidity 
     *         LP position that was minted. */
    function depositConduit(
        bytes32 poolHash,
        int24 lowTick,
        int24 highTick,
        uint128 liq,
        uint64 mileage,
        address lpConduit
    ) private {
        if (lpConduit != lockHolder_) {
            bool doesAccept =
                ICrocLpConduit(lpConduit).depositCrocLiq(lockHolder_, poolHash, lowTick, highTick, liq, mileage);
            require(doesAccept, "LP");
        }
    }

    /* @notice Withdraws and sends ownership of the ambient liquidity to a third party conduit
     *         explicitly nominated by the caller. */
    function withdrawConduit(bytes32 poolHash, uint128 liqSeeds, uint64 deflator, address lpConduit) private {
        withdrawConduit(poolHash, 0, 0, liqSeeds, deflator, lpConduit);
    }

    /* @notice Withdraws and sends ownership of the liquidity to a third party conduit
     *         explicitly nominated by the caller. */
    function withdrawConduit(
        bytes32 poolHash,
        int24 lowTick,
        int24 highTick,
        uint128 liq,
        uint64 mileage,
        address lpConduit
    ) private {
        if (lpConduit != lockHolder_) {
            bool doesAccept =
                ICrocLpConduit(lpConduit).withdrawCrocLiq(lockHolder_, poolHash, lowTick, highTick, liq, mileage);
            require(doesAccept, "LP");
        }
    }

    /* @notice Mints a new knockout liquidity position, or adds to a previous position, 
     *         and updates the curve and debit flows accordingly.
     *
     * @param curve The current state of the liquidity curve.
     * @param priceTick The 24-bit tick of the pool's current price
     * @param loc The location of where to mint the knockout liquidity
     * @param liquidity The total amount of XY=K liquidity to mint.
     * @param poolHash The hash of the pool the curve applies to
     * @param knockoutBits The bitwise knockout parameters currently set on the pool.
     *
     * @return The incrmental base and quote debit flows from this action. */
    function mintKnockout(
        CurveMath.CurveState memory curve,
        int24 priceTick,
        KnockoutLiq.KnockoutPosLoc memory loc,
        uint128 liquidity,
        bytes32 poolHash,
        uint8 knockoutBits
    ) internal returns (int128 baseFlow, int128 quoteFlow) {
        addKnockoutLiq(poolHash, knockoutBits, priceTick, curve.concGrowth_, loc, liquidity.liquidityToLots());

        (uint128 base, uint128 quote) = liquidityReceivable(curve, liquidity, loc.lowerTick_, loc.upperTick_);
        (baseFlow, quoteFlow) = signMintFlow(base, quote);
    }

    /* @notice Burns an existing knockout liquidity position and updates the curve
     *         and flows accordingly.
     *
     * @param curve The current state of the liquidity curve.
     * @param priceTick The 24-bit tick of the pool's current price
     * @param loc The location of where to burn the knockout liquidity from
     * @param liquidity The total amount of XY=K liquidity to mint.
     * @param poolHash The hash of the pool the curve applies to
     *
     * @return The incrmental base and quote debit flows from this action. */
    function burnKnockout(
        CurveMath.CurveState memory curve,
        int24 priceTick,
        KnockoutLiq.KnockoutPosLoc memory loc,
        uint128 liquidity,
        bytes32 poolHash
    ) internal returns (int128 baseFlow, int128 quoteFlow) {
        (,, uint64 rewards) = rmKnockoutLiq(poolHash, priceTick, curve.concGrowth_, loc, liquidity.liquidityToLots());

        (uint128 base, uint128 quote) = liquidityPayable(curve, liquidity, rewards, loc.lowerTick_, loc.upperTick_);
        (baseFlow, quoteFlow) = signBurnFlow(base, quote);
    }

    /* @notice Claims a post-knockout liquidity position using the ownership Merkle proof
     *         supplied by the caller.
     *
     * @param curve The current state of the liquidity curve.
     * @param loc The location of where the post-knockout position was placed
     * @param root The root of the supplied Merkle proof
     * @param proof The Merkle proof that combined with the root must match the current
     *              hash of the knockout slot
     * @param poolHash The hash of the pool the curve applies to
     *
     * @return The incrmental base and quote debit flows from this action. */
    function claimKnockout(
        CurveMath.CurveState memory curve,
        KnockoutLiq.KnockoutPosLoc memory loc,
        uint160 root,
        uint256[] memory proof,
        bytes32 poolHash
    ) internal returns (int128 baseFlow, int128 quoteFlow) {
        (uint96 lots, uint64 rewards) = claimPostKnockout(poolHash, loc, root, proof);
        uint128 liquidity = lots.lotsToLiquidity();

        (uint128 base, uint128 quote) = liquidityHeldPayable(curve, liquidity, rewards, loc);
        (baseFlow, quoteFlow) = signBurnFlow(base, quote);
    }

    /* @notice Claims a post-knockout liquidity position using the ownership Merkle proof
     *         supplied by the caller.
     *
     * @param curve The current state of the liquidity curve.
     * @param loc The location of where the post-knockout position was placed
     * @param root The root of the supplied Merkle proof
     * @param pivotTime The pivotTime of the knockout slot at the time the position was
     *                  minted.
     * @return The incrmental base and quote debit flows from this action. */
    function recoverKnockout(KnockoutLiq.KnockoutPosLoc memory loc, uint32 pivotTime, bytes32 poolHash)
        internal
        returns (int128 baseFlow, int128 quoteFlow)
    {
        uint96 lots = recoverPostKnockout(poolHash, loc, pivotTime);
        uint128 liquidity = lots.lotsToLiquidity();

        (uint128 base, uint128 quote) = liquidityHeldPayable(liquidity, loc);
        (baseFlow, quoteFlow) = signBurnFlow(base, quote);
    }

    /* @notice Harvests the accumulated rewards on a concentrated liquidity position.
     * 
     * @param curve The object representing the pre-loaded liquidity curve. Will be
     *              updated in memory after this call, but it's the caller's 
     *              responsbility to check it back into storage.
     * @param prickTick The tick index of the curve's current price.
     * @param lowTick The tick index of the lower boundary of the range order.
     * @param highTick The tick index of the upper boundary of the range order.
     * @param poolHash The hash indexing the pool this liquidity curve applies to.
     *
     * @return baseFlow The amount of base-side token collateral returned by this
     *                  operations. Will always be negative indicating, a credit from
     *                  the pool to the user.
     * @return quoteFlow The amount of quote-side token collateral returned by this
     *                   operation. */
    function harvestRange(
        CurveMath.CurveState memory curve,
        int24 priceTick,
        int24 lowTick,
        int24 highTick,
        bytes32 poolHash,
        address lpOwner
    ) internal returns (int128, int128) {
        uint64 feeMileage = clockFeeOdometer(poolHash, priceTick, lowTick, highTick, curve.concGrowth_);
        uint128 rewards = harvestPosLiq(lpOwner, poolHash, lowTick, highTick, feeMileage);
        withdrawConduit(poolHash, lowTick, highTick, 0, feeMileage, lpOwner);
        (uint128 base, uint128 quote) = liquidityPayable(curve, rewards);
        return signBurnFlow(base, quote);
    }

    /* @notice Converts the unsigned flow associated with a mint operation to a pair
     *         net settlement flow. (Will always be positive because a mint requires use
     *         to pay collateral to the pool.) */
    function signMintFlow(uint128 base, uint128 quote) private pure returns (int128, int128) {
        return (base.toInt128Sign(), quote.toInt128Sign());
    }

    /* @notice Converts the unsigned flow associated with a burn operation to a pair
     *         net settlement flow. (Will always be negative because a burn requires use
     *         to pay collateral to the pool.) */
    function signBurnFlow(uint128 base, uint128 quote) private pure returns (int128, int128) {
        return (-(base.toInt128Sign()), -(quote.toInt128Sign()));
    }

    /* @notice Executes the pending swap through the order book, adjusting the
     *         liquidity curve and level book as needed based on the swap's impact.
     *
     * @dev This is probably the most complex single function in the codebase. For
     *      small local moves, which don't cross extant levels in the book, it acts
     *      like a constant-product AMM curve. For large swaps which cross levels,
     *      it iteratively re-adjusts the AMM curve on every level cross, and performs
     *      the necessary book-keeping on each crossed level entry.
     *
     * @param accum The accumulator for the flows generated by the executable swap. 
     *              The realized flows on the swap will be written into the memory-based 
     *              accumulator fields of this struct. The caller is responsible for 
     *              ultaimtely paying and collecting those flows.
     * @param curve The starting liquidity curve state. Any changes created by the 
     *              swap on this struct are updated in memory. But the caller is 
     *              responsible for committing the final state to EVM storage.
     * @param midTick The price tick associated with the current price on the curve.
     * @param swap The user specified directive governing the size, direction and limit
     *             price of the swap to be executed.
     * @param pool The pool's market specification notably its swap fee rate and the
     *             protocol take rate. */
    function sweepSwapLiq(
        Chaining.PairFlow memory accum,
        CurveMath.CurveState memory curve,
        int24 midTick,
        Directives.SwapDirective memory swap,
        PoolSpecs.PoolCursor memory pool
    ) internal {
        require(swap.isBuy_ ? curve.priceRoot_ <= swap.limitPrice_ : curve.priceRoot_ >= swap.limitPrice_, "SD");

        // Keep iteratively executing more quantity until we either reach our limit price
        // or have zero quantity left to execute.
        bool doMore = true;
        while (doMore) {
            // Swap to furthest point we can based on the local bitmap. Don't bother
            // seeking a bump outside the local neighborhood yet, because we're not sure
            // if the swap will exhaust the bitmap.
            (int24 bumpTick, bool spillsOver) = pinBitmap(pool.hash_, swap.isBuy_, midTick);
            curve.swapToLimit(accum, swap, pool.head_, bumpTick);

            // The swap can be in one of four states at this point: 1) qty exhausted,
            // 2) limit price reached, 3) bump or barrier point reached on the curve.
            // The former two indicate the swap is complete. The latter means we have to
            // find the next bump point and possibly adjust AMM liquidity.
            doMore = hasSwapLeft(curve, swap);
            if (doMore) {
                // The spillsOver variable indicates that we reached stopped because we
                // reached the end of the local bitmap, rather than actually hitting a
                // level bump. Therefore we should query the global bitmap, find the next
                // bump point, and keep swapping across the constant-product curve until
                // if/when we hit that point.
                if (spillsOver) {
                    int24 liqTick = seekMezzSpill(pool.hash_, bumpTick, swap.isBuy_);
                    bool tightSpill = (bumpTick == liqTick);
                    bumpTick = liqTick;

                    // In some corner cases the local bitmap border also happens to
                    // be the next bump point. If so, we're done with this inner section.
                    // Otherwise, we keep swapping since we still have some distance on
                    // the curve to cover until we reach a bump point.
                    if (!tightSpill) {
                        curve.swapToLimit(accum, swap, pool.head_, bumpTick);
                        doMore = hasSwapLeft(curve, swap);
                    }
                }

                // Perform book-keeping related to crossing the level bump, update
                // the locally tracked tick of the curve price (rather than wastefully
                // we calculating it since we already know it), then begin the swap
                // loop again.
                if (doMore) {
                    midTick = knockInTick(accum, bumpTick, curve, swap, pool.hash_);
                }
            }
        }
    }

    /* @notice Determines if we've terminated the swap execution. I.e. fully exhausted
     *         the specified swap quantity *OR* hit the directive's limit price. */
    function hasSwapLeft(CurveMath.CurveState memory curve, Directives.SwapDirective memory swap)
        private
        pure
        returns (bool)
    {
        bool inLimit = swap.isBuy_ ? curve.priceRoot_ < swap.limitPrice_ : curve.priceRoot_ > swap.limitPrice_;
        return inLimit && (swap.qty_ > 0);
    }

    /* @notice Performs all the necessary book keeping related to crossing an extant 
     *         level bump on the curve. 
     *
     * @dev Note that this function updates the level book data structure directly on
     *      the EVM storage. But it only updates the liquidity curve state *in memory*.
     *      This is for gas efficiency reasons, as the same curve struct may be updated
     *      many times in a single swap. The caller must take responsibility for 
     *      committing the final curve state back to EVM storage. 
     *
     * @params bumpTick The tick index where the bump occurs.
     * @params isBuy The direction the bump happens from. If true, curve's price is 
     *               moving through the bump starting from a lower price and going to a
     *               higher price. If false, the opposite.
     * @params curve The pre-bump state of the local constant-product AMM curve. Updated
     *               to reflect the liquidity added/removed from rolling through the
     *               bump.
     * @param swap The user directive governing the size, direction and limit price of the
     *             swap to be executed.
     * @param poolHash The key hash mapping to the pool we're executive over. 
     *
     * @return The tick index that the curve and its price are living in after the call
     *         completes. */
    function knockInTick(
        Chaining.PairFlow memory accum,
        int24 bumpTick,
        CurveMath.CurveState memory curve,
        Directives.SwapDirective memory swap,
        bytes32 poolHash
    ) private returns (int24) {
        unchecked {
            if (!Bitmaps.isTickFinite(bumpTick)) return bumpTick;
            bumpLiquidity(curve, bumpTick, swap.isBuy_, poolHash);

            (int128 paidBase, int128 paidQuote, uint128 burnSwap) =
                curve.shaveAtBump(swap.inBaseQty_, swap.isBuy_, swap.qty_);
            accum.accumFlow(paidBase, paidQuote);

            // burn down qty from shaveAtBump is always validated to be less than remaining swap.qty_
            // so this will never underflow
            swap.qty_ -= burnSwap;

            // When selling down, the next tick leg actually occurs *below* the bump tick
            // because the bump barrier is the first price on a tick.
            return swap.isBuy_ ? bumpTick : bumpTick - 1; // Valid ticks are well above {min(int128)-1}, so will never underflow
        }
    }

    /* @notice Performs the book-keeping related to crossing a concentrated liquidity 
     *         bump tick, and adjusts the in-memory curve object with the change of
     *         AMM liquidity. */
    function bumpLiquidity(CurveMath.CurveState memory curve, int24 bumpTick, bool isBuy, bytes32 poolHash) private {
        (int128 liqDelta, bool knockoutFlag) = crossLevel(poolHash, bumpTick, isBuy, curve.concGrowth_);
        curve.concLiq_ = curve.concLiq_.addDelta(liqDelta);

        if (knockoutFlag) {
            int128 knockoutDelta = callCrossFlag(poolHash, bumpTick, isBuy, curve.concGrowth_);
            curve.concLiq_ = curve.concLiq_.addDelta(knockoutDelta);
        }
    }
}

/* @title Market sequencer.
 * @notice Mixin class that's responsibile for coordinating one or multiple sequetial
 *         trade actions within a single liqudity pool. */
contract MarketSequencer is TradeMatcher {
    using SafeCast for int256;
    using SafeCast for int128;
    using SafeCast for uint256;
    using SafeCast for uint128;
    using TickMath for uint128;
    using PoolSpecs for PoolSpecs.Pool;
    using SwapCurve for CurveMath.CurveState;
    using CurveRoll for CurveMath.CurveState;
    using CurveMath for CurveMath.CurveState;
    using CurveCache for CurveCache.Cache;
    using Directives for Directives.ConcentratedDirective;
    using PriceGrid for PriceGrid.ImproveSettings;
    using Chaining for Chaining.PairFlow;
    using Chaining for Chaining.RollTarget;

    /* @notice Performs a sequence of an arbitrary potential combination of mints, 
     *         burns, and swaps on a single pool. 
     *
     * @param flow Output accumulator, into which we'll net and and add the token flows 
     *             associated with the trade actions in this call.
     * @param dir A directive specifying an arbitrary sequences of action.
     * @param cntx Provides the execution context for the operation, including the pool
     *             to execute on and it's pre-loaded specs, off-grid price improvement
     *             settings, and parameters for rolling gap-failled quantities if they
     *             appear in the directive. */
    function tradeOverPool(
        Chaining.PairFlow memory flow,
        Directives.PoolDirective memory dir,
        Chaining.ExecCntx memory cntx
    ) internal {
        // To avoid repeatedly loading and storing the curve on each operation, we load
        // it once into memory...
        CurveCache.Cache memory curve;
        curve.curve_ = snapCurve(cntx.pool_.hash_);
        applyToCurve(flow, dir, curve, cntx);
        /// ...Then check it back into storage when complete
        commitCurve(cntx.pool_.hash_, curve.curve_);
    }

    /* @notice Performs a single swap over the pool.
     * @param dir The user-specified directive governing the size, direction and limit
     *            price of the swap to be performed.
     * @param pool The pre-loaded speciication and hash of the pool to be swapped against.
     * @return flow The net token flows generated by the swap. */
    function swapOverPool(Directives.SwapDirective memory dir, PoolSpecs.PoolCursor memory pool)
        internal
        returns (Chaining.PairFlow memory flow)
    {
        CurveMath.CurveState memory curve = snapCurve(pool.hash_);
        sweepSwapLiq(flow, curve, curve.priceRoot_.getTickAtSqrtRatio(), dir, pool);
        commitCurve(pool.hash_, curve);
    }

    /* @notice Mints concentrated liquidity in the form of a range order on to the pool.
     *
     * @param bidTick The price tick associated with the lower boundary of the range
     *                order.
     * @param askTick The price tick associated with the upper boundary of the range
     *                order.
     * @param liq The amount of liquidity being minted represented as the equivalent to
     *            sqrt(X*Y) in a constant product AMM pool.
     * @param pool The pre-loaded speciication and hash of the pool to be swapped against.
     * @param minPrice The minimum acceptable curve price to mint liquidity. If curve
     *                 price falls outside this point, the transaction is reverted.
     * @param maxPrice The maximum acceptable curve price to mint liquidity. If curve
     *                 price falls outside this point, the transaction is reverted.
     * @param lpConduit The address of the ICrocLpConduit that the liquidity will be
     *                  assigned to (0 for user owned liquidity).
     *
     * @return baseFlow The total amount of base-side token collateral that must be
     *                  committed to the pool as part of the mint. Will always be
     *                  positive as it's paid to the pool from the user.
     * @return quoteFlow The total amount of quote-side token collateral that must be
     *                   committed to the pool as part of the mint. */
    function mintOverPool(
        int24 bidTick,
        int24 askTick,
        uint128 liq,
        PoolSpecs.PoolCursor memory pool,
        uint128 minPrice,
        uint128 maxPrice,
        address lpConduit
    ) internal returns (int128 baseFlow, int128 quoteFlow) {
        CurveMath.CurveState memory curve = snapCurveInRange(pool.hash_, minPrice, maxPrice);
        (baseFlow, quoteFlow) =
            mintRange(curve, curve.priceRoot_.getTickAtSqrtRatio(), bidTick, askTick, liq, pool.hash_, lpConduit);
        PriceGrid.verifyFit(bidTick, askTick, pool.head_.tickSize_);
        commitCurve(pool.hash_, curve);
    }

    /* @notice Burns concentrated liquidity in the form of a range order on to the pool.
     *
     * @param bidTick The price tick associated with the lower boundary of the range
     *                order.
     * @param askTick The price tick associated with the upper boundary of the range
     *                order.
     * @param liq The amount of liquidity to burn represented as the equivalent to
     *            sqrt(X*Y) in a constant product AMM pool.
     * @param pool The pre-loaded speciication and hash of the pool to be swapped against.
     * @param minPrice The minimum acceptable curve price to mint liquidity. If curve
     *                 price falls outside this point, the transaction is reverted.
     * @param maxPrice The maximum acceptable curve price to mint liquidity. If curve
     *                 price falls outside this point, the transaction is reverted.
     *
     * @return baseFlow The total amount of base-side token collateral that is returned
     *                  from the pool as part of the burn. Will always be
     *                  negative as it's paid from the pool to the user.
     * @return quoteFlow The total amount of quote-side token collateral that is returned
     *                   from the pool as part of the burn. */
    function burnOverPool(
        int24 bidTick,
        int24 askTick,
        uint128 liq,
        PoolSpecs.PoolCursor memory pool,
        uint128 minPrice,
        uint128 maxPrice,
        address lpConduit
    ) internal returns (int128 baseFlow, int128 quoteFlow) {
        CurveMath.CurveState memory curve = snapCurveInRange(pool.hash_, minPrice, maxPrice);
        (baseFlow, quoteFlow) =
            burnRange(curve, curve.priceRoot_.getTickAtSqrtRatio(), bidTick, askTick, liq, pool.hash_, lpConduit);
        commitCurve(pool.hash_, curve);
    }

    /* @notice Harvests rewards from a concentrated liquidity position.
     *
     * @param bidTick The price tick associated with the lower boundary of the range
     *                order.
     * @param askTick The price tick associated with the upper boundary of the range
     *                order.
     * @param pool The pre-loaded speciication and hash of the pool to be swapped against.
     * @param minPrice The minimum acceptable curve price to mint liquidity. If curve
     *                 price falls outside this point, the transaction is reverted.
     * @param maxPrice The maximum acceptable curve price to mint liquidity. If curve
     *                 price falls outside this point, the transaction is reverted.
     *
     * @return baseFlow The total amount of base-side token collateral that is returned
     *                  from the pool as part of the burn. Will always be
     *                  negative as it's paid from the pool to the user.
     * @return quoteFlow The total amount of quote-side token collateral that is returned
     *                   from the pool as part of the burn. */
    function harvestOverPool(
        int24 bidTick,
        int24 askTick,
        PoolSpecs.PoolCursor memory pool,
        uint128 minPrice,
        uint128 maxPrice,
        address lpConduit
    ) internal returns (int128 baseFlow, int128 quoteFlow) {
        CurveMath.CurveState memory curve = snapCurveInRange(pool.hash_, minPrice, maxPrice);
        (baseFlow, quoteFlow) =
            harvestRange(curve, curve.priceRoot_.getTickAtSqrtRatio(), bidTick, askTick, pool.hash_, lpConduit);
        commitCurve(pool.hash_, curve);
    }

    /* @notice Mints ambient liquidity on to the pool's curve.
     *
     * @param liq The amount of liquidity being minted represented as the equivalent to
     *            sqrt(X*Y) in a constant product AMM pool.
     * @param pool The pre-loaded speciication and hash of the pool to be swapped against.
     * @param minPrice The minimum acceptable curve price to mint liquidity. If curve
     *                 price falls outside this point, the transaction is reverted.
     * @param maxPrice The maximum acceptable curve price to mint liquidity. If curve
     *                 price falls outside this point, the transaction is reverted.
     * @param lpConduit The address of the ICrocLpConduit that the liquidity will be
     *                  assigned to (0 for user owned liquidity).
     *
     * @return baseFlow The total amount of base-side token collateral that must be
     *                  committed to the pool as part of the mint. Will always be
     *                  positive as it's paid to the pool from the user.
     * @return quoteFlow The total amount of quote-side token collateral that must be
     *                   committed to the pool as part of the mint. */
    function mintOverPool(
        uint128 liq,
        PoolSpecs.PoolCursor memory pool,
        uint128 minPrice,
        uint128 maxPrice,
        address lpConduit
    ) internal returns (int128 baseFlow, int128 quoteFlow) {
        CurveMath.CurveState memory curve = snapCurveInRange(pool.hash_, minPrice, maxPrice);
        (baseFlow, quoteFlow) = mintAmbient(curve, liq, pool.hash_, lpConduit);
        commitCurve(pool.hash_, curve);
    }

    /* @notice Burns ambient liquidity on to the pool's curve.
     *
     * @param liq The amount of liquidity to burn represented as the equivalent to
     *            sqrt(X*Y) in a constant product AMM pool.
     * @param pool The pre-loaded speciication and hash of the pool to be swapped against.
     * @param minPrice The minimum acceptable curve price to mint liquidity. If curve
     *                 price falls outside this point, the transaction is reverted.
     * @param maxPrice The maximum acceptable curve price to mint liquidity. If curve
     *                 price falls outside this point, the transaction is reverted.
     *
     * @return baseFlow The total amount of base-side token collateral that is returned
     *                  from the pool as part of the burn. Will always be negative
     *                  as it's paid from the pool to the user.
     * @return quoteFlow The total amount of quote-side token collateral that is returned
     *                   from the pool as part of the burn. */
    function burnOverPool(
        uint128 liq,
        PoolSpecs.PoolCursor memory pool,
        uint128 minPrice,
        uint128 maxPrice,
        address lpConduit
    ) internal returns (int128 baseFlow, int128 quoteFlow) {
        CurveMath.CurveState memory curve = snapCurveInRange(pool.hash_, minPrice, maxPrice);
        (baseFlow, quoteFlow) = burnAmbient(curve, liq, pool.hash_, lpConduit);
        commitCurve(pool.hash_, curve);
    }

    /* @notice Initializes a new liquidity curve for the pool.
       
     * @dev This does *not* check whether the curve was previously initialized. It's
     *      the caller's responsibility to make sure this is never called on an already
     *      initialized pool.
     *
     * @param pool The pre-loaded speciication and hash of the pool to be swapped against.
     * @param price The initial price to set the curve at. Represented as the square root
     *              of price in Q64.64 fixed point.
     * @param initLiq The initial ambient liquidity commitment that will be permanetely 
     *                locked in the pool. Represeted as sqrt(X*Y) constant-product AMM
     *                liquidity.
     *
     * @return baseFlow The total amount of base-side token collateral that must be
     *                  committed to the pool as part of the mint. Will always be
     *                  positive as it's paid to the pool from the user.
     * @return quoteFlow The total amount of quote-side token collateral that must be
     *                   committed to the pool as part of the mint. */
    function initCurve(PoolSpecs.PoolCursor memory pool, uint128 price, uint128 initLiq)
        internal
        returns (int128 baseFlow, int128 quoteFlow)
    {
        CurveMath.CurveState memory curve = snapCurveInit(pool.hash_);
        initPrice(curve, price);
        if (initLiq == 0) initLiq = 1;
        (baseFlow, quoteFlow) = lockAmbient(curve, initLiq);
        commitCurve(pool.hash_, curve);
    }

    /* @notice Appplies the pool directive on to a pre-loaded liquidity curve. */
    function applyToCurve(
        Chaining.PairFlow memory flow,
        Directives.PoolDirective memory dir,
        CurveCache.Cache memory curve,
        Chaining.ExecCntx memory cntx
    ) private {
        if (!dir.chain_.swapDefer_) {
            applySwap(flow, dir.swap_, curve, cntx);
        }
        applyAmbient(flow, dir.ambient_, curve, cntx);
        applyConcentrated(flow, dir.conc_, curve, cntx);
        if (dir.chain_.swapDefer_) {
            applySwap(flow, dir.swap_, curve, cntx);
        }
    }

    /* @notice Applies the swap directive on to a pre-loaded liquidity curve. */
    function applySwap(
        Chaining.PairFlow memory flow,
        Directives.SwapDirective memory dir,
        CurveCache.Cache memory curve,
        Chaining.ExecCntx memory cntx
    ) private {
        cntx.roll_.plugSwapGap(dir, flow);
        if (dir.qty_ != 0) {
            callSwap(flow, curve, dir, cntx.pool_);
        }
    }

    /* @notice Applies an ambient liquidity directive to a pre-loaded liquidity curve. */
    function applyAmbient(
        Chaining.PairFlow memory flow,
        Directives.AmbientDirective memory dir,
        CurveCache.Cache memory curve,
        Chaining.ExecCntx memory cntx
    ) private {
        cntx.roll_.plugLiquidity(dir, curve.curve_, flow);

        if (dir.liquidity_ > 0) {
            (int128 base, int128 quote) = dir.isAdd_
                ? callMintAmbient(curve, dir.liquidity_, cntx.pool_.hash_)
                : callBurnAmbient(curve, dir.liquidity_, cntx.pool_.hash_);

            flow.accumFlow(base, quote);
        }
    }

    /* @notice Applies zero, one or a series of concentrated liquidity directives to a 
     *         pre-loaded liquidity curve. */
    function applyConcentrated(
        Chaining.PairFlow memory flow,
        Directives.ConcentratedDirective[] memory dirs,
        CurveCache.Cache memory curve,
        Chaining.ExecCntx memory cntx
    ) private {
        unchecked {
            // Only arithmetic in block is ++i which will never overflow
            for (uint256 i = 0; i < dirs.length; ++i) {
                (int128 nextBase, int128 nextQuote) = applyConcentrated(curve, flow, cntx, dirs[i]);
                flow.accumFlow(nextBase, nextQuote);
            }
        }
    }

    /* Applies a single concentrated liquidity range order to the liquidity curve. */
    function applyConcentrated(
        CurveCache.Cache memory curve,
        Chaining.PairFlow memory flow,
        Chaining.ExecCntx memory cntx,
        Directives.ConcentratedDirective memory bend
    ) private returns (int128, int128) {
        // If ticks are relative, normalize against current pool price.
        if (bend.isTickRel_) {
            int24 priceTick = curve.pullPriceTick();
            bend.lowTick_ = priceTick + bend.lowTick_;
            bend.highTick_ = priceTick + bend.highTick_;
            require(
                (bend.lowTick_ >= TickMath.MIN_TICK) && (bend.highTick_ <= TickMath.MAX_TICK)
                    && (bend.lowTick_ <= bend.highTick_),
                "RT"
            );
        }

        // If liquidity is set based on rolling balance, dynamically set in base
        // liquidity space.
        cntx.roll_.plugLiquidity(bend, curve.curve_, bend.lowTick_, bend.highTick_, flow);

        if (bend.isAdd_) {
            bool offGrid = cntx.improve_.verifyFit(
                bend.lowTick_, bend.highTick_, bend.liquidity_, cntx.pool_.head_.tickSize_, curve.pullPriceTick()
            );

            // Off-grid positions are only eligible when the LP has committed
            // to a minimum liquidity commitment above some threshold. This opens
            // up the possibility of a user minting an off-grid LP position above the
            // the threshold, then partially burning the position to resize the position *below*
            // the threhsold.
            // To prevent this all off-grid positions are marked as atomic which prevents partial
            // (but not full) burns. An off-grid LP wishing to reduce their position must fully
            // burn the position, then mint a new position, which will be checked that it meets
            // the size threshold at mint time.
            if (offGrid) {
                markPosAtomic(lockHolder_, cntx.pool_.hash_, bend.lowTick_, bend.highTick_);
            }
        }

        if (bend.liquidity_ == 0) return (0, 0);
        return bend.isAdd_
            ? callMintRange(curve, bend.lowTick_, bend.highTick_, bend.liquidity_, cntx.pool_.hash_)
            : callBurnRange(curve, bend.lowTick_, bend.highTick_, bend.liquidity_, cntx.pool_.hash_);
    }
}

/// @title Minimal ERC20 interface for Uniswap
/// @notice Contains a subset of the full ERC20 interface that is used in Uniswap V3
interface IERC20Minimal {
    /// @notice Returns the balance of a token
    /// @param account The account for which to look up the number of tokens it has, i.e. its balance
    /// @return The number of tokens held by the account
    function balanceOf(address account) external view returns (uint256);

    /// @notice Transfers the amount of token from the `msg.sender` to the recipient
    /// @param recipient The account that will receive the amount transferred
    /// @param amount The number of tokens to send from the sender to the recipient
    /// @return Returns true for a successful transfer, false for an unsuccessful transfer
    function transfer(address recipient, uint256 amount) external returns (bool);

    /// @notice Returns the current allowance given to a spender by an owner
    /// @param owner The account of the token owner
    /// @param spender The account of the token spender
    /// @return The current allowance granted by `owner` to `spender`
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Sets the allowance of a spender from the `msg.sender` to the value `amount`
    /// @param spender The account which will be allowed to spend a given amount of the owners tokens
    /// @param amount The amount of tokens allowed to be used by `spender`
    /// @return Returns true for a successful approval, false for unsuccessful
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Transfers `amount` tokens from `sender` to `recipient` up to the allowance given to the `msg.sender`
    /// @param sender The account from which the transfer will be initiated
    /// @param recipient The recipient of the transfer
    /// @param amount The amount of the transfer
    /// @return Returns true for a successful transfer, false for unsuccessful
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /// @notice Event emitted when tokens are transferred from one address to another, either via `#transfer` or `#transferFrom`.
    /// @param from The account from which the tokens were sent, i.e. the balance decreased
    /// @param to The account to which the tokens were sent, i.e. the balance increased
    /// @param value The amount of tokens that were transferred
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Event emitted when the approval amount for the spender of a given owner's tokens changes.
    /// @param owner The account that approved spending of its tokens
    /// @param spender The account for which the spending allowance was modified
    /// @param value The new allowance from the owner to the spender
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Permit is IERC20Minimal {
    function permit(address owner, address spender, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
}

/// @title TransferHelper
/// @notice Contains helper methods for interacting with ERC20 tokens that do not consistently return true/false
library TransferHelper {
    /// @notice Transfers tokens from msg.sender to a recipient
    /// @dev Calls transfer on token contract, errors with TF if transfer fails
    /// @param token The contract address of the token which will be transferred
    /// @param to The recipient of the transfer
    /// @param value The value of the transfer
    function safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20Minimal.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TF");
    }

    /// @notice Transfers tokens from msg.sender to a recipient
    /// @dev Calls transferFrom on token contract, errors with TF if transfer fails
    /// @param token The contract address of the token which will be transferred
    /// @param from The sender address of the transfer
    /// @param to The recipient of the transfer
    /// @param value The value of the transfer
    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20Minimal.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TF");
    }

    // @notice Transfers native Ether to a recipient.
    // @dev errors with TF if transfer fails
    function safeEtherSend(address to, uint256 value) internal {
        (bool success,) = to.call{value: value}("");
        require(success, "TF");
    }
}

/* @title Settle layer mixin
 * @notice Provides facilities for settling, previously determined, collateral flows
 *         between the user and the exchange. Supports both ERC20 tokens as well as
 *         native Ethereum as asset collateral. */
contract SettleLayer is AgentMask {
    using SafeCast for uint256;
    using SafeCast for uint128;
    using TokenFlow for address;

    /* @notice Completes the user<->exchange collateral settlement at the final hop
     *         in the transaction. Settles both the token from the last leg in the chain
     *         as well as closes out the previous net Ether flows.
     * 
     * @dev    This method settles any net Ether debits or credits in the ethFlows
     *         argument, by consuming the native ETH attached in msg.value, using
     *         popMsgVal(). popMsgVal() sets a transaction level flag, and to prevent
     *         double spent will revert and fail the top level CrocSwapDex contract
     *         call if ever called twice in the same transction. Therefore this method
     *         must only be called at most once per transaction, otherwise the top-level
     *         CrocSwapDex contract call will revert and fail.  
     *
     * @param flow The net flow for this settlement leg. Negative for credits paid to
     *             user, positive for debits.
     * @param dir The directive governing the details of how the user once the leg 
     *            settled.
     * @param ethFlows Any prior Ether-specific flows from previous legs. (This final
     *            leg may also be denominated in Eth, and this param should *not* include
     *            the current leg's value.) */
    function settleFinal(int128 flow, Directives.SettlementChannel memory dir, int128 ethFlows) internal {
        (address debitor, address creditor) = agentsSettle();
        settleFinal(debitor, creditor, flow, dir, ethFlows);
    }

    /* @notice Completes the user<->exchange collateral settlement on an intermediate hop
     *         leg in the transaction. For ERC20 tokens the flow will be settled at this
     *         call. For native Ether flows, the net flow will be returned to be deferred
     *         until the settleFinal() call. This is because we potentially have multiple
     *         native Eth settlement legs and want to avoid a msg.value double spend.
     *
     * @param flow The net flow for this settlement leg. Negative for credits paid to
     *             user, positive for debits.
     * @param dir The directive governing the details of how the user once the leg 
     *            settled.
     * @return ethFlows Any native Eth flows associated with this leg. It's the caller's
     *                  responsibility to accumulate and sum this value for all calls,
     *                  then pass to settleFinal() at the end of the transaction. */
    function settleLeg(int128 flow, Directives.SettlementChannel memory dir) internal returns (int128 ethFlows) {
        (address debitor, address creditor) = agentsSettle();
        return settleLeg(debitor, creditor, flow, dir);
    }

    /* @notice Completes the user<->exchange collateral settlement at the final hop
     *         in the transaction. Settles both the token from the last leg in the chain
     *         as well as closes out the previous net Ether flows.
     * 
     * @dev   This call is the point where any Ether debit 
     Because this actually collects any Ether debit (using msg.value), this
     *         function must be called *exactly once* as the final settlement call in
     *         a transaction. Otherwise, a double-spend is possible.
     *
     * @param debitor The address from which any debts to the exchange should be 
     *                collected.
     * @param creditor The address to which any credits owed to the user should be paid.
     * @param flow The net flow for this settlement leg. Negative for credits paid to
     *             user, positive for debits.
     * @param dir The directive governing the details of how the user once the leg 
     *            settled.
     * @param ethFlows Any prior Ether-specific flows from previous legs. (This final
     *            leg may also be denominated in Eth, and this param should *not* include
     *            the current leg's value.) */
    function settleFinal(
        address debitor,
        address creditor,
        int128 flow,
        Directives.SettlementChannel memory dir,
        int128 ethFlows
    ) internal {
        ethFlows += settleLeg(debitor, creditor, flow, dir);
        transactEther(debitor, creditor, ethFlows, dir.useSurplus_);
    }

    /* @notice Completes the user<->exchange collateral settlement on an intermediate hop
     *         leg in the transaction. For ERC20 tokens the flow will be settled at this
     *         call. For native Ether flows, the net flow will be returned to be deferred
     *         until the settleFinal() call. This is because we potentially have multiple
     *         native Eth settlement legs and want to avoid a msg.value double spend.
     *
     * @param debitor The address from which any debts to the exchange should be 
     *                collected.
     * @param creditor The address to which any credits owed to the user should be paid.
     * @param flow The net flow for this settlement leg. Negative for credits paid to
     *             user, positive for debits.
     * @param dir The directive governing the details of how the user once the leg 
     *            settled.
     * @return ethFlows Any native Eth flows associated with this leg. It's the caller's
     *                  responsibility to accumulate and sum this value for all calls,
     *                  then pass to settleFinal() at the end of the transaction. */
    function settleLeg(address debitor, address creditor, int128 flow, Directives.SettlementChannel memory dir)
        internal
        returns (int128 ethFlows)
    {
        require(passesLimit(flow, dir.limitQty_), "K");
        if (moreThanDust(flow, dir.dustThresh_)) {
            ethFlows = pumpFlow(debitor, creditor, flow, dir.token_, dir.useSurplus_);
        }
    }

    /* @notice Settle the collateral exchange associated with a single bilateral pair.
     *         Useful and gas efficient when there's only one pair in the transaction.
     * @param base The ERC20 address of the base token collateral in the pair (if 0x0 
     *             indicates that the collateral is native Eth).
     * @param quote The ERC20 address of the quote token collateral in the pair.
     * @param baseFlow The amount of flow associated with the base side of the pair. 
     *                 Negative for credits paid to user, positive for debits.
     * @param quoteFlow The flow associated with the quote side of the pair.
     * @param reserveFlags Bitwise flags to indicate whether the base and/or quote flows
     *                     should be settled from caller's surplus collateral */
    function settleFlows(address base, address quote, int128 baseFlow, int128 quoteFlow, uint8 reserveFlags) internal {
        (address debitor, address creditor) = agentsSettle();
        settleFlat(debitor, creditor, base, baseFlow, quote, quoteFlow, reserveFlags);
    }

    /* @notice Settle the collateral exchange associated with a the initailization of
     *         a new pool in the exchange.
     * @oaran recv The address that will be covering any debits associated with the
     *             initialization of the pool.
     * @param base The ERC20 address of the base token collateral in the pair (if 0x0 
     *             indicates that the collateral is native Eth).
     * @param baseFlow The amount of flow associated with the base side of the pair. 
     *                 By convention negative for credits paid to user, positive for debits,
     *                 but will always be positive/debit for this operation.
     * @param quote The ERC20 address of the quote token collateral in the pair.
     * @param quoteFlow The flow associated with the quote side of the pair. */
    function settleInitFlow(address recv, address base, int128 baseFlow, address quote, int128 quoteFlow) internal {
        (uint256 baseSnap, uint256 quoteSnap) = snapOpenBalance(base, quote);
        settleFlat(recv, recv, base, baseFlow, quote, quoteFlow, BOTH_RESERVE_FLAGS);
        assertCloseMatches(base, baseSnap, baseFlow);
        assertCloseMatches(quote, quoteSnap, quoteFlow);
    }

    /* @notice Settles the collateral exchanged associated with the flow in a single 
     *         pair.
     * @dev    This must only be used when no other pairs settle in the transaction. */
    function settleFlat(
        address debitor,
        address creditor,
        address base,
        int128 baseFlow,
        address quote,
        int128 quoteFlow,
        uint8 reserveFlags
    ) private {
        if (base.isEtherNative()) {
            transactEther(debitor, creditor, baseFlow, useReservesBase(reserveFlags));
        } else {
            transactToken(debitor, creditor, baseFlow, base, useReservesBase(reserveFlags));
        }

        // Because Ether native trapdoor is 0x0 address, and because base is always
        // smaller of the two addresses, native ETH will always appear on the base
        // side.
        transactToken(debitor, creditor, quoteFlow, quote, useReservesQuote(reserveFlags));
    }

    function useReservesBase(uint8 reserveFlags) private pure returns (bool) {
        return reserveFlags & BASE_RESERVE_FLAG > 0;
    }

    function useReservesQuote(uint8 reserveFlags) private pure returns (bool) {
        return reserveFlags & QUOTE_RESERVE_FLAG > 0;
    }

    uint8 constant NO_RESERVE_FLAGS = 0x0;
    uint8 constant BASE_RESERVE_FLAG = 0x1;
    uint8 constant QUOTE_RESERVE_FLAG = 0x2;
    uint8 constant BOTH_RESERVE_FLAGS = 0x3;

    /* @notice Performs check to make sure the new balance matches the expected 
     * transfer amount. */
    function assertCloseMatches(address token, uint256 open, int128 expected) private view {
        if (token != address(0)) {
            uint256 close = IERC20Minimal(token).balanceOf(address(this));
            require(close >= open && expected >= 0 && close - open >= uint128(expected), "TD");
        }
    }

    /* @notice Snapshots the DEX contract's ERC20 token balance at call time. */
    function snapOpenBalance(address base, address quote) private view returns (uint256 openBase, uint256 openQuote) {
        openBase = base == address(0) ? 0 : IERC20Minimal(base).balanceOf(address(this));
        openQuote = IERC20Minimal(quote).balanceOf(address(this));
    }

    /* @notice Given a pre-determined amount of flow, settles according to collateral 
     *         type and settlement specification. */
    function pumpFlow(address debitor, address creditor, int128 flow, address token, bool useReserves)
        private
        returns (int128)
    {
        if (token.isEtherNative()) {
            return flow;
        } else {
            transactToken(debitor, creditor, flow, token, useReserves);
            return 0;
        }
    }

    function querySurplus(address user, address token) internal view returns (uint128) {
        bytes32 key = tokenKey(user, token);
        return userBals_[key].surplusCollateral_;
    }

    /* @notice Returns true if the flow represents a debit owed from the user to the
     *         exchange. */
    function isDebit(int128 flow) private pure returns (bool) {
        return flow > 0;
    }

    /* @notice Returns true if the flow represents a credit owed from the exchange to the
     *         user. */
    function isCredit(int128 flow) private pure returns (bool) {
        return flow < 0;
    }

    /* @notice Called to settle a net balance of native Ether.
     * @dev Becaue this settles against msg.value, it's very important to *never* call
     *      this twice in any single transaction, to avoid double-spend.
     *
     * @param debitor The address to collect any net debit from.
     * @param creditor The address to pay out any net credit to.
     * @param flow The total net balance to be settled. Negative indicates credit to the
     *             user. Positive debit to the exchange.
     * @para useReserves If true, any settlement is first done against the user's surplus
     *                   collateral account at the exchange rather than sending Ether. */
    function transactEther(address debitor, address creditor, int128 flow, bool useReserves) private {
        // This is the only point in a standard transaction where msg.value is accessed.
        uint128 recvEth = popMsgVal();
        if (flow != 0) {
            transactFlow(debitor, creditor, flow, address(0), recvEth, useReserves);
        } else {
            refundEther(creditor, recvEth);
        }
    }

    /* @notice Called to settle a net balance of ERC20 tokens
     * @dev transactEther Unlike transactEther this can be called multiple times, even
     *      on the same token.
     *
     * @param debitor The address to collect any net debit from.
     * @param creditor The address to pay out any net credit to.
     * @param flow The total net balance to be settled. Negative indicates credit to the
     *             user. Positive debit to the exchange.
     * @param token The address of the token's ERC20 tracker.
     * @para useReserves If true, any settlement is first done against the user's surplus
     *                   collateral account at the exchange. */
    function transactToken(address debitor, address creditor, int128 flow, address token, bool useReserves) private {
        require(!token.isEtherNative());
        // Since this is a token settlement, we defer booking any native ETH in msg.value
        uint128 bookedEth = 0;
        transactFlow(debitor, creditor, flow, token, bookedEth, useReserves);
    }

    /* @notice Handles the single sided settlement of a token or native ETH flow. */
    function transactFlow(
        address debitor,
        address creditor,
        int128 flow,
        address token,
        uint128 bookedEth,
        bool useReserves
    ) private {
        if (isDebit(flow)) {
            debitUser(debitor, uint128(flow), token, bookedEth, useReserves);
        } else if (isCredit(flow)) {
            creditUser(creditor, uint128(-flow), token, bookedEth, useReserves);
        }
    }

    /* @notice Collects a collateral debit from the user depending on the asset type
     *         and the settlement specifcation. */
    function debitUser(address recv, uint128 value, address token, uint128 bookedEth, bool useReserves) private {
        if (useReserves) {
            uint128 remainder = debitSurplus(recv, value, token);
            debitRemainder(recv, remainder, token, bookedEth);
        } else {
            debitTransfer(recv, value, token, bookedEth);
        }
    }

    /* @notice Collects the remaining debit (if any) after the user's surplus collateral
     *         balance has been exhausted. */
    function debitRemainder(address recv, uint128 remainder, address token, uint128 bookedEth) private {
        if (remainder > 0) {
            debitTransfer(recv, remainder, token, bookedEth);
        } else if (token.isEtherNative()) {
            refundEther(recv, bookedEth);
        }
    }

    /* @notice Pays out a collateral credit to the user depending on asset type and 
     *         settlement specification. */
    function creditUser(address recv, uint128 value, address token, uint128 bookedEth, bool useReserves) private {
        if (useReserves) {
            creditSurplus(recv, value, token);
            creditRemainder(recv, token, bookedEth);
        } else {
            creditTransfer(recv, value, token, bookedEth);
        }
    }

    /* @notice Handles any refund necessary after a credit has been paid to the user's 
     *         surplus collateral balance. */
    function creditRemainder(address recv, address token, uint128 bookedEth) private {
        if (token.isEtherNative()) {
            refundEther(recv, bookedEth);
        }
    }

    /* @notice Settles a credit with an external transfer to user. */
    function creditTransfer(address recv, uint128 value, address token, uint128 bookedEth) internal {
        if (token.isEtherNative()) {
            payEther(recv, value, bookedEth);
        } else {
            TransferHelper.safeTransfer(token, recv, value);
        }
    }

    /* @notice Settles a debit with an external transfer from user. */
    function debitTransfer(address recv, uint128 value, address token, uint128 bookedEth) internal {
        if (token.isEtherNative()) {
            collectEther(recv, value, bookedEth);
        } else {
            collectToken(recv, value, token);
        }
    }

    /* @notice Pays a native Ethereum credit to the user (and refunds any overpay in
     *         the transction, since by definition they have no debit.) */
    function payEther(address recv, uint128 value, uint128 overpay) private {
        TransferHelper.safeEtherSend(recv, value + overpay);
    }

    /* @notice Collects a debt in the form of native Ether. Since the only way to pay
     *         Ether is as msg.value, this function checks that's sufficient to cover
     *         the debt and pays the difference as a refund.
     * @dev Because of the risk of double-spend, this must *never* be called more than
     *      once in a transaction.
     * @param recv The address to send any over-payment refunds to.
     * @param value The amount of Ether owed to the exchange. msg.value must exceed
     *              this threshold.
     * @param paidEth The amount of Ether paid by the user in this transaction (usually
     *                msg.value) */
    function collectEther(address recv, uint128 value, uint128 paidEth) private {
        require(paidEth >= value, "EC");
        uint128 overpay = paidEth - value;
        refundEther(recv, overpay);
    }

    /* @notice Refunds any overpaid native Eth (if any) */
    function refundEther(address recv, uint128 overpay) private {
        if (overpay > 0) {
            TransferHelper.safeEtherSend(recv, overpay);
        }
    }

    /* @notice Collects a token debt from a specfic debtor.
     * @dev    Note that this function does *not* assert that the post-transfer balance
     *         is correct. CrocSwap is not safe to use for any fee-on-transfer tokens
     *         or any other tokens that break ERC20 transfer functionality.
     *
     * @param recv The address of the debtor being collected from.
     * @param value The total amount of tokens being collected.
     * @param token The address of the ERC20 token tracker. */
    function collectToken(address recv, uint128 value, address token) private {
        TransferHelper.safeTransferFrom(token, recv, address(this), value);
    }

    /* @notice Credits a user's surplus collateral account at the exchange (instead of
     *         directly sending the tokens to their address) */
    function creditSurplus(address recv, uint128 value, address token) private {
        bytes32 key = tokenKey(recv, token);
        userBals_[key].surplusCollateral_ += value;
    }

    /* @notice Debits the tokens owed from the user's pre-existing surplus collateral
     *         balance at the exchange.
     * @return remainder The amount of the debit that cannot be satisfied by surplus
     *                   collateral alone (0 othersize). */
    function debitSurplus(address recv, uint128 value, address token) private returns (uint128 remainder) {
        bytes32 key = tokenKey(recv, token);
        UserBalance storage bal = userBals_[key];
        uint128 balance = bal.surplusCollateral_;

        if (balance > value) {
            bal.surplusCollateral_ -= value;
        } else {
            bal.surplusCollateral_ = 0;
            remainder = value - balance;
        }
    }

    /* @notice Returns true if the net settled flow is equal or better to the user's
     *         minimum expected amount. (Otherwise upstream should revert the tx.) */
    function passesLimit(int128 flow, int128 limitQty) private pure returns (bool) {
        return flow <= limitQty;
    }

    /* @notice If true, determines that the settlement flow should be ignored because
     *         it's economically meaningless and not worth transacting. */
    function moreThanDust(int128 flow, uint128 dustThresh) private pure returns (bool) {
        if (isDebit(flow)) {
            return true;
        } else {
            return uint128(-flow) > dustThresh;
        }
    }
}

/* @notice Simple interface that defines the surface between the CrocSwapDex
 *         itself and protocol governance and policy. All governance actions are
 *         are executed through the single protocolCmd() method. */
interface ICrocMinion {
    /* @notice Calls a general governance authorized command on the CrocSwapDex contract.
     *
     * @param proxyPath The proxy callpath sidecar to execute the command within. (Will
     *                  call protocolCmd
     * @param cmd       The underlying command content to pass to the proxy sidecar call.
     *                  Will DELEGATECALL (protocolCmd(cmd) on the sidecar proxy.
     * @param sudo      Set to true for commands that require escalated privilege (e.g. 
     *                  authority transfers or upgrades.) The ability to call with sudo 
     *                  true should be reserved for privileged callpaths in the governance
     *                  controller contract. */
    function protocolCmd(uint16 proxyPath, bytes calldata cmd, bool sudo) external payable;
}

/* @notice Interface for a contract that directly governs a CrocSwap dex contract. */
interface ICrocMaster {
    /* @notice Used to validate governance contract to prevent authority transfer to an
     *         an invalid address or contract. */
    function acceptsCrocAuthority() external returns (bool);
}

/* @title Protocol Command library.
 *
 * @notice To allow for flexibility and upgradeability the top-level interface to the Croc
 *         dex contract contains a general purpose encoding scheme. User commands specify a
 *         proxy contract index, and input is passed raw and unformatted. Each proxy contract
 *         is free to specify its own input format, but by convention many proxy contracts
 *         adhere to a specification where the first 32 bytes of the input encodes a sub-command
 *         code. This library contains all of these sub-command codes in a single location for
 *         easy lookup. */
library ProtocolCmd {
    ////////////////////////////////////////////////////////////////////////////
    // Privileged commands invokable by direct governance only.
    ////////////////////////////////////////////////////////////////////////////
    // Code for transferring authority in the underlying CrocSwapDex contract.
    uint8 constant AUTHORITY_TRANSFER_CODE = 20;
    // Code to upgrade one of the sidecar proxy contracts on CrocSwapDex.
    uint8 constant UPGRADE_DEX_CODE = 21;
    // Code to force hot path to use the proxy contract
    uint8 constant HOT_OPEN_CODE = 22;
    // Code to toggle on or off emergency safe mode
    uint8 constant SAFE_MODE_CODE = 23;
    // Code to collect accumulated protocol fees for the treasury.
    uint8 constant COLLECT_TREASURY_CODE = 40;
    // Code to set the protocol treasury
    uint8 constant SET_TREASURY_CODE = 41;
    ////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////
    // General purpose policy commands.
    ////////////////////////////////////////////////////////////////////////////
    // Code to disable a given pool template
    uint8 constant DISABLE_TEMPLATE_CODE = 109;
    // Code to set pool type template
    uint8 constant POOL_TEMPLATE_CODE = 110;
    // Code to revise parameters on pre-existing pool
    uint8 constant POOL_REVISE_CODE = 111;
    // Code to set the liquidity burn on pool initialization
    uint8 constant INIT_POOL_LIQ_CODE = 112;
    // Code to set/reset the off-grid liquidity threshold.
    uint8 constant OFF_GRID_CODE = 113;
    // Code to set the protocol take rate
    uint8 constant SET_TAKE_CODE = 114;
    // Code to resync the protocol take rate on an extant pool
    uint8 constant RESYNC_TAKE_CODE = 115;
    uint8 constant RELAYER_TAKE_CODE = 116;
    ////////////////////////////////////////////////////////////////////////////

    function encodeHotPath(bool open) internal pure returns (bytes memory) {
        return abi.encode(HOT_OPEN_CODE, open);
    }

    function encodeSafeMode(bool safeMode) internal pure returns (bytes memory) {
        return abi.encode(SAFE_MODE_CODE, safeMode);
    }
}

library UserCmd {
    ////////////////////////////////////////////////////////////////////////////
    // General purpose cold path codes
    ////////////////////////////////////////////////////////////////////////////
    uint8 constant INIT_POOL_CODE = 71;
    uint8 constant APPROVE_ROUTER_CODE = 72;
    uint8 constant DEPOSIT_SURPLUS_CODE = 73;
    uint8 constant DISBURSE_SURPLUS_CODE = 74;
    uint8 constant TRANSFER_SURPLUS_CODE = 75;
    uint8 constant SIDE_POCKET_CODE = 76;
    uint8 constant DEPOSIT_VIRTUAL_CODE = 77;
    uint8 constant DISBURSE_VIRTUAL_CODE = 78;
    uint8 constant RESET_NONCE = 80;
    uint8 constant RESET_NONCE_COND = 81;
    uint8 constant GATE_ORACLE_COND = 82;
    uint8 constant DEPOSIT_PERMIT_CODE = 83;

    ////////////////////////////////////////////////////////////////////////////
    // LP action warm path command codes
    ////////////////////////////////////////////////////////////////////////////
    uint8 constant MINT_RANGE_LIQ_LP = 1;
    uint8 constant MINT_RANGE_BASE_LP = 11;
    uint8 constant MINT_RANGE_QUOTE_LP = 12;
    uint8 constant BURN_RANGE_LIQ_LP = 2;
    uint8 constant BURN_RANGE_BASE_LP = 21;
    uint8 constant BURN_RANGE_QUOTE_LP = 22;
    uint8 constant MINT_AMBIENT_LIQ_LP = 3;
    uint8 constant MINT_AMBIENT_BASE_LP = 31;
    uint8 constant MINT_AMBIENT_QUOTE_LP = 32;
    uint8 constant BURN_AMBIENT_LIQ_LP = 4;
    uint8 constant BURN_AMBIENT_BASE_LP = 41;
    uint8 constant BURN_AMBIENT_QUOTE_LP = 42;
    uint8 constant HARVEST_LP = 5;

    ////////////////////////////////////////////////////////////////////////////
    // Knockout LP command codes
    ////////////////////////////////////////////////////////////////////////////
    uint8 constant MINT_KNOCKOUT = 91;
    uint8 constant BURN_KNOCKOUT = 92;
    uint8 constant CLAIM_KNOCKOUT = 93;
    uint8 constant RECOVER_KNOCKOUT = 94;
}

/* @title Protocol Account Mixin
 * @notice Tracks and pays out the accumulated protocol fees across the entire exchange 
 *         These are the fees belonging to the CrocSwap protocol, not the liquidity 
 *         miners.
 * @dev Unlike liquidity fees, protocol fees are accumulated as resting tokens 
 *      instead of ambient liquidity. */
contract ProtocolAccount is StorageLayout {
    using SafeCast for uint256;
    using TokenFlow for address;

    /* @notice Called at the completion of a swap event, incrementing any protocol
     *         fees accumulated in the swap. */
    function accumProtocolFees(TokenFlow.PairSeq memory accum) internal {
        accumProtocolFees(accum.flow_, accum.baseToken_, accum.quoteToken_);
    }

    /* @notice Increments the protocol's account with the fees collected on the pair. */
    function accumProtocolFees(Chaining.PairFlow memory accum, address base, address quote) internal {
        if (accum.baseProto_ > 0) {
            feesAccum_[base] += accum.baseProto_;
        }
        if (accum.quoteProto_ > 0) {
            feesAccum_[quote] += accum.quoteProto_;
        }
    }

    /* @notice Pays out the earned, but unclaimed protocol fees in the pool.
     * @param recv - The receiver of the protocol fees.
     * @param token - The token address of the quote token. */
    function disburseProtocolFees(address recv, address token) internal {
        uint128 collected = feesAccum_[token];
        feesAccum_[token] = 0;
        if (collected > 0) {
            bytes32 payoutKey = keccak256(abi.encode(recv, token));
            userBals_[payoutKey].surplusCollateral_ += collected;
        }
    }
}

contract DepositDesk is SettleLayer {
    using SafeCast for uint256;

    /* @notice Directly deposits a certain amount of surplus collateral to a user's
     *         account.
     *
     * @dev    This call can be used both for token and native Ether collateral. For
     *         tokens, each call initiates a token transfer call to the ERC20 contract,
     *         and it's safe to call repeatedly in the same transaction even for the same
     *         token. 
     * 
     *         For native Ether deposits, the call consumes the value in msg.value using the
     *         popMsgVal() function. If called more than once in a single transction
     *         popMsgVal() will revert. Therefore if calling depositSurplus() on native ETH
     *         be aware than calling more than once in a single transaction result in the top-
     *         level CrocSwapDex contract call failing and reverting.
     *
     * @param recv The address of the owner associated with the account.
     * @param value The amount to be collected from owner and deposited.
     * @param token The ERC20 address of the token (or native Ether if set to 0x0) being
     *              deposited. */
    function depositSurplus(address recv, uint128 value, address token) internal {
        debitTransfer(lockHolder_, value, token, popMsgVal());
        bytes32 key = tokenKey(recv, token);
        userBals_[key].surplusCollateral_ += value;
    }

    /* @notice Same as deposit surplus, but used with EIP-2612 compliant tokens that have
     *         a permit function. Allows the user to avoid needing to approve() the DEX
     *         contract.
     *
     * @param recv  The address which will receive the surplus collateral balance
     * @param value The amount of tokens being deposited
     * @param token The address of the token deposited
     * @param deadline The deadline that this ERC20 permit call is valid for
     * @param v,r,s  The EIP-712 signature approviing Permit of the token underlying 
     *               token to be deposited. */
    function depositSurplusPermit(
        address recv,
        uint128 value,
        address token,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        IERC20Permit(token).permit(recv, address(this), value, deadline, v, r, s);
        depositSurplus(recv, value, token);
    }

    /* @notice Pays out surplus collateral held by the owner at the exchange.
     *
     * @dev There is no security check associated with this call. It's the caller's 
     *      responsibility of the caller to make sure the receiver is authorized to
     *      to collect the owner's balance.
     *
     * @param recv  The receiver where the collateral will be sent to.
     * @param size  The amount to be paid out. Owner's balance will be decremented 
     *              accordingly. Be aware this uses the following convention:
     *                  Positive - pay out the fixed size amount
     *                  Zero     - pays out the entire balance
     *                  Negative - pays out the entire balance *excluding* the size amount
     * @param token The ERC20 address of the token (or native Ether if set to 0x0) being
     *              disbursed. */
    function disburseSurplus(address recv, int128 size, address token) internal {
        bytes32 key = tokenKey(lockHolder_, token);
        uint128 balance = userBals_[key].surplusCollateral_;
        uint128 value = applyTransactVal(size, balance);

        // No need to use msg.value, because unlike trading there's no logical reason
        // we'd expect it to be set on this call.
        userBals_[key].surplusCollateral_ -= value;
        creditTransfer(recv, value, token, 0);
    }

    /* @notice Transfers surplus collateral from one user to another.
     * @param to The user account the surplus collateral will be sent from
     * @param size The total amount of surplus collateral to send. 
     *             Be aware this uses the following convention:
     *                  Positive - pay out the fixed size amount
     *                  Zero     - pays out the entire balance
     *                  Negative - pays out the entire balance *excluding* the size amount
     * @param token The address of the token the surplus collateral is sent for. */
    function transferSurplus(address to, int128 size, address token) internal {
        bytes32 fromKey = tokenKey(lockHolder_, token);
        bytes32 toKey = tokenKey(to, token);
        moveSurplus(fromKey, toKey, size);
    }

    /* @notice Moves an existing surplus collateral balance to a "side-pocket" , or a 
     *         separate balance tied to an arbitrary salt.
     *
     * @dev    This is primarily useful for pre-signed transactions. For example a user
     *         could move the bulk of their surplus collateral to a side-pocket to min
     *         what was at risk in their primary balance.
     *
     * @param fromSalt The side pocket salt the surplus balance is being moved from. Use
     *                 0 for the primary surplus collateral balance. 
     * @param toSalt The side pocket salt the surplus balance is being moved to. Use 0 for
     *               the primary surplus collateral balance.
     * @param size The total amount of surplus collateral to send.  
     *             Be aware this uses the following convention:
     *                  Positive - pay out the fixed size amount
     *                  Zero     - pays out the entire balance
     *                  Negative - pays out the entire balance *excluding* the size amount
     * @param token The address of the token the surplus collateral is sent for. */
    function sidePocketSurplus(uint256 fromSalt, uint256 toSalt, int128 size, address token) internal {
        address from = virtualizeUser(lockHolder_, fromSalt);
        address to = virtualizeUser(lockHolder_, toSalt);
        bytes32 fromKey = tokenKey(from, token);
        bytes32 toKey = tokenKey(to, token);
        moveSurplus(fromKey, toKey, size);
    }

    /* @notice Lower level function to move surplus collateral from one fully salted 
     *         (user+token+side pocket) to another fully salted slot. */
    function moveSurplus(bytes32 fromKey, bytes32 toKey, int128 size) private {
        uint128 balance = userBals_[fromKey].surplusCollateral_;
        uint128 value = applyTransactVal(size, balance);

        userBals_[fromKey].surplusCollateral_ -= value;
        userBals_[toKey].surplusCollateral_ += value;
    }

    /* @notice Converts an encoded transfer argument to the actual quantity to transfer.
     *         Includes syntactic sugar for special transfer types including:
     *            Positive Value - Transfer this specified amount
     *            Zero Value - Transfer the full balance
     *            Negative Value - Transfer everything *above* this specified amount. */
    function applyTransactVal(int128 qty, uint128 balance) private pure returns (uint128 value) {
        if (qty < 0) {
            value = balance - uint128(-qty);
        } else if (qty == 0) {
            value = balance;
        } else {
            value = uint128(qty);
        }
        require(value <= balance, "SC");
    }
}

library CrocEvents {
    /* @notice Emitted when governance authority for CrocSwapDex is transfered.
     * @param The authority being transfered to. */
    event AuthorityTransfer(address indexed authority);

    /* @notice Indicates a new pool liquidity initialization value is set.
     * @param liq The pool initialization value. */
    event SetNewPoolLiq(uint128 liq);

    /* @notice Emitted when a new protocol take rate is set.
     * @param takeRate The take rate represents in units of 1/256. */
    event SetTakeRate(uint8 takeRate);

    /* @notice Emitted when a new protocol relayer take rate is set.
     * @param takeRate The relayer take rate represents in units of 1/256. */
    event SetRelayerTakeRate(uint8 takeRate);

    /* @notice Emitted when a new template is disabled, halting new creation of that pool type.
     * @param poolIdx The pool type index being disabled. */
    event DisablePoolTemplate(uint256 indexed poolIdx);

    /* @notice Emitted when a new template is written or overwrriten.
     * @param poolIdx The pool type index being disabled.
     * @param feeRate The swap fee rate for the pool (represented in units of 0.0001%)
     * @param tickSize The minimum tick size for range orders in the pool.
     * @param jitThresh The JIT liquiidty TTL time in the pool (represented in 10s of seconds)
     * @param knockout The knockout liquidity paramter bits (see KnockoutLiq library for more detail)
     * @param oracleFlags The permissioned pool oracle flags if this is setup as a permissioned pool. */
    event SetPoolTemplate(
        uint256 indexed poolIdx, uint16 feeRate, uint16 tickSize, uint8 jitThresh, uint8 knockout, uint8 oracleFlags
    );

    /* @notice Emitted when a previously created pool with a pre-existing protocol take rate is re-
     *         sychronized to the current dex-wide protocol take rate setting. 
     * @param base The base token of the pool.
     * @param quote The quote token of the pool.
     * @param poolIdx The pool type index of the pool.
     * @param takeRate The newly set protocol take rate of the pool. */
    event ResyncTakeRate(address indexed base, address indexed quote, uint256 indexed poolIdx, uint8 takeRate);

    /* @notice Emitted when new minimum thresholds are set for off-grid price improvement liquidity
     *         thresholds.
     * @param token The token the thresholds apply to.
     * @param unitTickCollateral The size of commited collateral required to mint positions off-grid
     * @param awayTickTol The maximum distance away an off-grid range can be minted from the current
     *                    price tick. */
    event PriceImproveThresh(address indexed token, uint128 unitTickCollateral, uint16 awayTickTol);

    /* @notice Emitted when protocol governance sets a new teasury vault address
     * @param treasury The address the treasury vault is set to
     * @param startTime The earliest time that the vault will be eligible to collect protocol fees. */
    event TreasurySet(address indexed treasury, uint64 indexed startTime);

    /* @notice Emitted when accumulated protocol fees are collected by the treasury.
     * @param token The token of the fees being collected.
     * @param recv The vault the collected fees are being paid to. */
    event ProtocolDividend(address indexed token, address indexed recv);

    /* @notice Called when any proxy sidecar contract is upgraded.
     * @param proxy The address of the new proxy smart contract.
     * @param proxyIdx The proxy sidecar index slot the upgrade is applied to. */
    event UpgradeProxy(address indexed proxy, uint16 proxyIdx);

    /* @notice Called whenever the hot path open is toggled.
     * @param If true indicates the hot-path is open and users can directly call the swap() function
     *        If false, the hot path is closed and users must call the proxy contract to swap. */
    event HotPathOpen(bool);

    /* @notice Called whenever emergency safe mode is toggled
     * @param If true indicates emergency safe mode is turned on
     *        If false indicates emergency safe mode is turned off */
    event SafeMode(bool);
}

/* @title Cold path callpath sidecar.
 * @notice Defines a proxy sidecar contract that's used to move code outside the 
 *         main contract to avoid Ethereum's contract code size limit. Contains
 *         top-level logic for non trade related logic, including protocol control,
 *         pool initialization, and surplus collateral payment. 
 * 
 * @dev    This exists as a standalone contract but will only ever contain proxy code,
 *         not state. As such it should never be called directly or externally, and should
 *         only be invoked with DELEGATECALL so that it operates on the contract state
 *         within the primary CrocSwap contract. */
contract ColdPath is MarketSequencer, DepositDesk, ProtocolAccount {
    using SafeCast for uint128;
    using TokenFlow for TokenFlow.PairSeq;
    using CurveMath for CurveMath.CurveState;
    using Chaining for Chaining.PairFlow;
    using ProtocolCmd for bytes;

    /* @notice Consolidated method for protocol control related commands. */
    function protocolCmd(bytes calldata cmd) public virtual {
        uint8 code = uint8(cmd[31]);

        if (code == ProtocolCmd.DISABLE_TEMPLATE_CODE) {
            disableTemplate(cmd);
        } else if (code == ProtocolCmd.POOL_TEMPLATE_CODE) {
            setTemplate(cmd);
        } else if (code == ProtocolCmd.POOL_REVISE_CODE) {
            revisePool(cmd);
        } else if (code == ProtocolCmd.SET_TAKE_CODE) {
            setTakeRate(cmd);
        } else if (code == ProtocolCmd.RELAYER_TAKE_CODE) {
            setRelayerTakeRate(cmd);
        } else if (code == ProtocolCmd.RESYNC_TAKE_CODE) {
            resyncTakeRate(cmd);
        } else if (code == ProtocolCmd.INIT_POOL_LIQ_CODE) {
            setNewPoolLiq(cmd);
        } else if (code == ProtocolCmd.OFF_GRID_CODE) {
            pegPriceImprove(cmd);
        } else {
            sudoCmd(cmd);
        }
    }

    /* @notice Subset of highly privileged commands that are only allowed to run in sudo
     *         mode. */
    function sudoCmd(bytes calldata cmd) internal {
        require(sudoMode_, "Sudo");
        uint8 cmdCode = uint8(cmd[31]);

        if (cmdCode == ProtocolCmd.COLLECT_TREASURY_CODE) {
            collectProtocol(cmd);
        } else if (cmdCode == ProtocolCmd.SET_TREASURY_CODE) {
            setTreasury(cmd);
        } else if (cmdCode == ProtocolCmd.AUTHORITY_TRANSFER_CODE) {
            transferAuthority(cmd);
        } else if (cmdCode == ProtocolCmd.HOT_OPEN_CODE) {
            setHotPathOpen(cmd);
        } else if (cmdCode == ProtocolCmd.SAFE_MODE_CODE) {
            setSafeMode(cmd);
        } else {
            revert("Invalid command");
        }
    }

    function userCmd(bytes calldata cmd) public payable virtual {
        uint8 cmdCode = uint8(cmd[31]);

        if (cmdCode == UserCmd.INIT_POOL_CODE) {
            initPool(cmd);
        } else if (cmdCode == UserCmd.APPROVE_ROUTER_CODE) {
            approveRouter(cmd);
        } else if (cmdCode == UserCmd.DEPOSIT_SURPLUS_CODE) {
            depositSurplus(cmd);
        } else if (cmdCode == UserCmd.DEPOSIT_PERMIT_CODE) {
            depositPermit(cmd);
        } else if (cmdCode == UserCmd.DISBURSE_SURPLUS_CODE) {
            disburseSurplus(cmd);
        } else if (cmdCode == UserCmd.TRANSFER_SURPLUS_CODE) {
            transferSurplus(cmd);
        } else if (cmdCode == UserCmd.SIDE_POCKET_CODE) {
            sidePocketSurplus(cmd);
        } else if (cmdCode == UserCmd.RESET_NONCE) {
            resetNonce(cmd);
        } else if (cmdCode == UserCmd.RESET_NONCE_COND) {
            resetNonceCond(cmd);
        } else if (cmdCode == UserCmd.GATE_ORACLE_COND) {
            checkGateOracle(cmd);
        } else {
            revert("Invalid command");
        }
    }

    /* @notice Initializes the pool type for the pair.
     * @param base The base token in the pair.
     * @param quote The quote token in the pair.
     * @param poolIdx The index of the pool type to initialize.
     * @param price The price to initialize the pool. Represented as square root price in
     *              Q64.64 notation. */
    function initPool(bytes calldata cmd) private {
        (, address base, address quote, uint256 poolIdx, uint128 price) =
            abi.decode(cmd, (uint8, address, address, uint256, uint128));

        (PoolSpecs.PoolCursor memory pool, uint128 initLiq) = registerPool(base, quote, poolIdx);

        verifyPermitInit(pool, base, quote, poolIdx);

        (int128 baseFlow, int128 quoteFlow) = initCurve(pool, price, initLiq);
        settleInitFlow(lockHolder_, base, baseFlow, quote, quoteFlow);
    }

    /* @notice Disables an existing pool template. Any previously instantiated pools on
     *         this template will continue exist, but calling this will prevent any new
     *         pools from being created on this template. */
    function disableTemplate(bytes calldata input) private {
        (, uint256 poolIdx) = abi.decode(input, (uint8, uint256));
        emit CrocEvents.DisablePoolTemplate(poolIdx);
        disablePoolTemplate(poolIdx);
    }

    /* @notice Sets template parameters for a pool type index.
     * @param poolIdx The index of the pool type.
     * @param feeRate The pool's swap fee rate in multiples of 0.0001%
     * @param tickSize The pool's grid size in ticks.
     * @param jitThresh The minimum resting time (in seconds) for concentrated LPs.
     * @param knockout The knockout bits for the pool template.
     @ @param oracleFlags The oracle bit flags if a permissioned pool. */
    function setTemplate(bytes calldata input) private {
        (, uint256 poolIdx, uint16 feeRate, uint16 tickSize, uint8 jitThresh, uint8 knockout, uint8 oracleFlags) =
            abi.decode(input, (uint8, uint256, uint16, uint16, uint8, uint8, uint8));

        emit CrocEvents.SetPoolTemplate(poolIdx, feeRate, tickSize, jitThresh, knockout, oracleFlags);
        setPoolTemplate(poolIdx, feeRate, tickSize, jitThresh, knockout, oracleFlags);
    }

    function setTakeRate(bytes calldata input) private {
        (, uint8 takeRate) = abi.decode(input, (uint8, uint8));

        emit CrocEvents.SetTakeRate(takeRate);
        setProtocolTakeRate(takeRate);
    }

    function setRelayerTakeRate(bytes calldata input) private {
        (, uint8 takeRate) = abi.decode(input, (uint8, uint8));

        emit CrocEvents.SetRelayerTakeRate(takeRate);
        setRelayerTakeRate(takeRate);
    }

    function setNewPoolLiq(bytes calldata input) private {
        (, uint128 liq) = abi.decode(input, (uint8, uint128));

        emit CrocEvents.SetNewPoolLiq(liq);
        setNewPoolLiq(liq);
    }

    function resyncTakeRate(bytes calldata input) private {
        (, address base, address quote, uint256 poolIdx) = abi.decode(input, (uint8, address, address, uint256));

        emit CrocEvents.ResyncTakeRate(base, quote, poolIdx, protocolTakeRate_);
        resyncProtocolTake(base, quote, poolIdx);
    }

    /* @notice Update parameters for a pre-existing pool.
     * @param base The base-side token defining the pool's pair.
     * @param quote The quote-side token defining the pool's pair.
     * @param poolIdx The index of the pool type.
     * @param feeRate The pool's swap fee rate in multiples of 0.0001%
     * @param tickSize The pool's grid size in ticks.
     * @param jitThresh The minimum resting time (in seconds) for concentrated LPs in
     *                  in the pool.
     * @param knockout The knockout bit flags for the pool. */
    function revisePool(bytes calldata cmd) private {
        (
            ,
            address base,
            address quote,
            uint256 poolIdx,
            uint16 feeRate,
            uint16 tickSize,
            uint8 jitThresh,
            uint8 knockout
        ) = abi.decode(cmd, (uint8, address, address, uint256, uint16, uint16, uint8, uint8));
        setPoolSpecs(base, quote, poolIdx, feeRate, tickSize, jitThresh, knockout);
    }

    /* @notice Set off-grid price improvement.
     * @param token The token the settings apply to.
     * @param unitTickCollateral The collateral threshold for off-grid price improvement.
     * @param awayTickTol The maximum tick distance from current price that off-grid
     *                    quotes are allowed for. */
    function pegPriceImprove(bytes calldata cmd) private {
        (, address token, uint128 unitTickCollateral, uint16 awayTickTol) =
            abi.decode(cmd, (uint8, address, uint128, uint16));
        emit CrocEvents.PriceImproveThresh(token, unitTickCollateral, awayTickTol);
        setPriceImprove(token, unitTickCollateral, awayTickTol);
    }

    function setHotPathOpen(bytes calldata cmd) private {
        (, bool open) = abi.decode(cmd, (uint8, bool));
        emit CrocEvents.HotPathOpen(open);
        hotPathOpen_ = open;
    }

    function setSafeMode(bytes calldata cmd) private {
        (, bool inSafeMode) = abi.decode(cmd, (uint8, bool));
        emit CrocEvents.SafeMode(inSafeMode);
        inSafeMode_ = inSafeMode;
    }

    /* @notice Pays out the the protocol fees.
     * @param token The token for which the accumulated fees are being paid out. 
     *              (Or if 0x0 pays out native Ethereum.) */
    function collectProtocol(bytes calldata cmd) private {
        (, address token) = abi.decode(cmd, (uint8, address));

        require(block.timestamp >= treasuryStartTime_, "Treasury start");
        emit CrocEvents.ProtocolDividend(token, treasury_);
        disburseProtocolFees(treasury_, token);
    }

    /* @notice Sets the treasury address to receive protocol fees. Once set, the treasury cannot
     *         receive fees until 7 days after. */
    function setTreasury(bytes calldata cmd) private {
        (, address treasury) = abi.decode(cmd, (uint8, address));

        require(treasury != address(0) && treasury.code.length != 0, "Treasury invalid");
        treasury_ = treasury;
        treasuryStartTime_ = uint64(block.timestamp + 7 days);
        emit CrocEvents.TreasurySet(treasury_, treasuryStartTime_);
    }

    function transferAuthority(bytes calldata cmd) private {
        (, address auth) = abi.decode(cmd, (uint8, address));

        require(
            auth != address(0) && auth.code.length > 0 && ICrocMaster(auth).acceptsCrocAuthority(), "Invalid Authority"
        );

        emit CrocEvents.AuthorityTransfer(authority_);
        authority_ = auth;
    }

    /* @notice Used to directly pay out or pay in surplus collateral.
     * @param recv The address where the funds are paid to (only applies if surplus was
     *             paid out.)
     * @param value The amount of surplus collateral being paid or received. If negative
     *              paid from the user into the pool, increasing their balance.
     * @param token The token to which the surplus collateral is applied. (If 0x0, then
     *              native Ethereum) */
    function depositSurplus(bytes calldata cmd) private {
        (, address recv, uint128 value, address token) = abi.decode(cmd, (uint8, address, uint128, address));
        depositSurplus(recv, value, token);
    }

    function depositPermit(bytes calldata cmd) private {
        (, address recv, uint128 value, address token, uint256 deadline, uint8 v, bytes32 r, bytes32 s) =
            abi.decode(cmd, (uint8, address, uint128, address, uint256, uint8, bytes32, bytes32));
        depositSurplusPermit(recv, value, token, deadline, v, r, s);
    }

    function disburseSurplus(bytes calldata cmd) private {
        (, address recv, int128 value, address token) = abi.decode(cmd, (uint8, address, int128, address));
        disburseSurplus(recv, value, token);
    }

    function transferSurplus(bytes calldata cmd) private {
        (, address recv, int128 size, address token) = abi.decode(cmd, (uint8, address, int128, address));
        transferSurplus(recv, size, token);
    }

    function sidePocketSurplus(bytes calldata cmd) private {
        (, uint256 fromSalt, uint256 toSalt, int128 value, address token) =
            abi.decode(cmd, (uint8, uint256, uint256, int128, address));
        sidePocketSurplus(fromSalt, toSalt, value, token);
    }

    function resetNonce(bytes calldata cmd) private {
        (, bytes32 salt, uint32 nonce) = abi.decode(cmd, (uint8, bytes32, uint32));
        resetNonce(salt, nonce);
    }

    function resetNonceCond(bytes calldata cmd) private {
        (, bytes32 salt, uint32 nonce, address oracle, bytes memory args) =
            abi.decode(cmd, (uint8, bytes32, uint32, address, bytes));
        resetNonceCond(salt, nonce, oracle, args);
    }

    function checkGateOracle(bytes calldata cmd) private {
        (, address oracle, bytes memory args) = abi.decode(cmd, (uint8, address, bytes));
        checkGateOracle(oracle, args);
    }

    /* @notice Called by a user to give permissions to an external smart contract router.
     * @param router The address of the external smart contract that the user is giving
     *                permission to.
     * @param nCalls The number of calls the router agent is approved for.
     * @param callpaths The proxy sidecar indexes the router is approved for */
    function approveRouter(bytes calldata cmd) private {
        (, address router, uint32 nCalls, uint16[] memory callpaths) =
            abi.decode(cmd, (uint8, address, uint32, uint16[]));

        for (uint256 i = 0; i < callpaths.length; ++i) {
            require(callpaths[i] != CrocSlots.COLD_PROXY_IDX, "Invalid Router Approve");
            approveAgent(router, nCalls, callpaths[i]);
        }
    }

    /* @notice Used at upgrade time to verify that the contract is a valid Croc sidecar proxy and used
     *         in the correct slot. */
    function acceptCrocProxyRole(address, uint16 slot) public virtual returns (bool) {
        return slot == CrocSlots.COLD_PROXY_IDX;
    }
}

/* @title Booth path callpath sidecar.
 * 
 * @notice Simple proxy with the sole function of upgrading other proxy contracts. For safety
 *         this proxy cannot upgrade itself, since that would risk permenately locking out the
 *         ability to ever upgrade.
 *         
 * @dev    This is a special proxy sidecar which should only be installed once at construction
 *         time at slot 0 (BOOT_PROXY_IDX). No other proxy contract should include upgrade 
 *         functionality. If both of these conditions are true, this proxy can never be overwritten
 *         and upgrade functionality can never be broken for the life of the main contract. */
contract BootPath is StorageLayout {
    using ProtocolCmd for bytes;

    /* @notice Consolidated method for protocol control related commands. */
    function protocolCmd(bytes calldata cmd) public virtual {
        require(sudoMode_, "Sudo");

        uint8 cmdCode = uint8(cmd[31]);
        if (cmdCode == ProtocolCmd.UPGRADE_DEX_CODE) {
            upgradeProxy(cmd);
        } else {
            revert("Invalid command");
        }
    }

    function userCmd(bytes calldata) public payable virtual {
        revert("Invalid command");
    }

    /* @notice Upgrades one of the existing proxy sidecar contracts.
     * @dev    Be extremely careful calling this, particularly when upgrading the
     *         cold path contract, since that contains the upgrade code itself.
     * @param proxy The address of the new proxy smart contract
     * @param proxyIdx Determines which proxy is upgraded on this call */
    function upgradeProxy(bytes calldata cmd) private {
        (, address proxy, uint16 proxyIdx) = abi.decode(cmd, (uint8, address, uint16));

        require(proxyIdx != CrocSlots.BOOT_PROXY_IDX, "Cannot overwrite boot path");
        require(proxy == address(0) || proxy.code.length > 0, "Proxy address is not a contract");

        emit CrocEvents.UpgradeProxy(proxy, proxyIdx);
        proxyPaths_[proxyIdx] = proxy;

        if (proxy != address(0)) {
            bool doesAccept = BootPath(proxy).acceptCrocProxyRole(address(this), proxyIdx);
            require(doesAccept, "Proxy does not accept role");
        }
    }

    /* @notice Conforms to the standard call, but should always reject role because this contract
     *         should only ever be installled once at construction time and never upgraded after */
    function acceptCrocProxyRole(address, uint16) public pure virtual returns (bool) {
        return false;
    }
}

/* @title Warm path callpath sidecar.
 * @notice Defines a proxy sidecar contract that's used to move code outside the 
 *         main contract to avoid Ethereum's contract code size limit. Contains top-
 *         level logic for the core liquidity provider actions:
 *              * Mint ambient liquidity
 *              * Mint concentrated range liquidity
 *              * Burn ambient liquidity
 *              * Burn concentrated range liquidity
 *         These methods are exposed as atomic single-action calls. Useful for traders
 *         who only need to execute a single action, and want to get the lowest gas fee
 *         possible. Compound calls are available in LongPath, but the overhead with
 *         parsing a longer OrderDirective makes the gas cost higher.
 * 
 * @dev    This exists as a standalone contract but will only ever contain proxy code,
 *         not state. As such it should never be called directly or externally, and should
 *         only be invoked with DELEGATECALL so that it operates on the contract state
 *         within the primary CrocSwap contract. */
contract WarmPath is MarketSequencer, SettleLayer, ProtocolAccount {
    using SafeCast for uint128;
    using TokenFlow for TokenFlow.PairSeq;
    using CurveMath for CurveMath.CurveState;
    using Chaining for Chaining.PairFlow;

    /* @notice Consolidated method for all atomic liquidity provider actions.
     * @dev    We consolidate multiple call types into a single method to reduce the 
     *         contract size in the main contract by paring down methods.
     * 
     * @param code The command code corresponding to the actual method being called. */
    function userCmd(bytes calldata input) public payable returns (int128 baseFlow, int128 quoteFlow) {
        (
            uint8 code,
            address base,
            address quote,
            uint256 poolIdx,
            int24 bidTick,
            int24 askTick,
            uint128 liq,
            uint128 limitLower,
            uint128 limitHigher,
            uint8 reserveFlags,
            address lpConduit
        ) = abi.decode(
            input, (uint8, address, address, uint256, int24, int24, uint128, uint128, uint128, uint8, address)
        );

        if (lpConduit == address(0)) lpConduit = lockHolder_;

        (baseFlow, quoteFlow) =
            commitLP(code, base, quote, poolIdx, bidTick, askTick, liq, limitLower, limitHigher, lpConduit);
        settleFlows(base, quote, baseFlow, quoteFlow, reserveFlags);
    }

    function commitLP(
        uint8 code,
        address base,
        address quote,
        uint256 poolIdx,
        int24 bidTick,
        int24 askTick,
        uint128 liq,
        uint128 limitLower,
        uint128 limitHigher,
        address lpConduit
    ) private returns (int128, int128) {
        if (code == UserCmd.MINT_RANGE_LIQ_LP) {
            return mintConcentratedLiq(base, quote, poolIdx, bidTick, askTick, liq, lpConduit, limitLower, limitHigher);
        } else if (code == UserCmd.MINT_RANGE_BASE_LP) {
            return mintConcentratedQty(
                base, quote, poolIdx, bidTick, askTick, true, liq, lpConduit, limitLower, limitHigher
            );
        } else if (code == UserCmd.MINT_RANGE_QUOTE_LP) {
            return mintConcentratedQty(
                base, quote, poolIdx, bidTick, askTick, false, liq, lpConduit, limitLower, limitHigher
            );
        } else if (code == UserCmd.BURN_RANGE_LIQ_LP) {
            return burnConcentratedLiq(base, quote, poolIdx, bidTick, askTick, liq, lpConduit, limitLower, limitHigher);
        } else if (code == UserCmd.BURN_RANGE_BASE_LP) {
            return burnConcentratedQty(
                base, quote, poolIdx, bidTick, askTick, true, liq, lpConduit, limitLower, limitHigher
            );
        } else if (code == UserCmd.BURN_RANGE_QUOTE_LP) {
            return burnConcentratedQty(
                base, quote, poolIdx, bidTick, askTick, false, liq, lpConduit, limitLower, limitHigher
            );
        } else if (code == UserCmd.MINT_AMBIENT_LIQ_LP) {
            return mintAmbientLiq(base, quote, poolIdx, liq, lpConduit, limitLower, limitHigher);
        } else if (code == UserCmd.MINT_AMBIENT_BASE_LP) {
            return mintAmbientQty(base, quote, poolIdx, true, liq, lpConduit, limitLower, limitHigher);
        } else if (code == UserCmd.MINT_AMBIENT_QUOTE_LP) {
            return mintAmbientQty(base, quote, poolIdx, false, liq, lpConduit, limitLower, limitHigher);
        } else if (code == UserCmd.BURN_AMBIENT_LIQ_LP) {
            return burnAmbientLiq(base, quote, poolIdx, liq, lpConduit, limitLower, limitHigher);
        } else if (code == UserCmd.BURN_AMBIENT_BASE_LP) {
            return burnAmbientQty(base, quote, poolIdx, true, liq, lpConduit, limitLower, limitHigher);
        } else if (code == UserCmd.BURN_AMBIENT_QUOTE_LP) {
            return burnAmbientQty(base, quote, poolIdx, false, liq, lpConduit, limitLower, limitHigher);
        } else if (code == UserCmd.HARVEST_LP) {
            return harvest(base, quote, poolIdx, bidTick, askTick, lpConduit, limitLower, limitHigher);
        } else {
            revert("Invalid command");
        }
    }

    /* @notice Mints liquidity as a concentrated liquidity range order.
     * @param base The base-side token in the pair.
     * @param quote The quote-side token in the par.
     * @param poolIdx The index of the pool type being minted on.
     * @param bidTick The price tick index of the lower boundary of the range order.
     * @param askTick The price tick index of the upper boundary of the range order.
     * @param liq The total amount of liquidity being minted. Represented as sqrt(X*Y)
     *            for the equivalent constant-product AMM.
     * @param lpConduit The address of the LP conduit to deposit the minted position at
     *                  (direct owned liquidity if 0)
     * @param limitLower Exists to make sure the user is happy with the price the 
     *                   liquidity is minted at. Transaction fails if the curve price
     *                   at call time is below this value.
     * @param limitUpper Transaction fails if the curve price at call time is above this
     *                   threshold.  */
    function mintConcentratedLiq(
        address base,
        address quote,
        uint256 poolIdx,
        int24 bidTick,
        int24 askTick,
        uint128 liq,
        address lpConduit,
        uint128 limitLower,
        uint128 limitHigher
    ) internal returns (int128, int128) {
        PoolSpecs.PoolCursor memory pool = queryPool(base, quote, poolIdx);
        verifyPermitMint(pool, base, quote, bidTick, askTick, liq);

        return mintOverPool(bidTick, askTick, liq, pool, limitLower, limitHigher, lpConduit);
    }

    /* @notice Burns liquidity as a concentrated liquidity range order.
     * @param base The base-side token in the pair.
     * @param quote The quote-side token in the par.
     * @param poolIdx The index of the pool type being burned on.
     * @param bidTick The price tick index of the lower boundary of the range order.
     * @param askTick The price tick index of the upper boundary of the range order.
     * @param liq The total amount of liquidity being burned. Represented as sqrt(X*Y)
     *            for the equivalent constant-product AMM.
     * @param lpConduit The address of the LP conduit to deposit the minted position at
     *                  (direct owned liquidity if 0)
     * @param limitLower Exists to make sure the user is happy with the price the 
     *                   liquidity is burned at. Transaction fails if the curve price
     *                   at call time is below this value.
     * @param limitUpper Transaction fails if the curve price at call time is above this
     *                   threshold. */
    function burnConcentratedLiq(
        address base,
        address quote,
        uint256 poolIdx,
        int24 bidTick,
        int24 askTick,
        uint128 liq,
        address lpConduit,
        uint128 limitLower,
        uint128 limitHigher
    ) internal returns (int128, int128) {
        PoolSpecs.PoolCursor memory pool = queryPool(base, quote, poolIdx);
        verifyPermitBurn(pool, base, quote, bidTick, askTick, liq);

        return burnOverPool(bidTick, askTick, liq, pool, limitLower, limitHigher, lpConduit);
    }

    /* @notice Harvests the rewards for a concentrated liquidity position.
     * @param base The base-side token in the pair.
     * @param quote The quote-side token in the par.
     * @param poolIdx The index of the pool type being burned on.
     * @param bidTick The price tick index of the lower boundary of the range order.
     * @param askTick The price tick index of the upper boundary of the range order.
     * @param lpConduit The address of the LP conduit to deposit the minted position at
     *                  (direct owned liquidity if 0)
     * @param limitLower Exists to make sure the user is happy with the price the 
     *                   liquidity is burned at. Transaction fails if the curve price
     *                   at call time is below this value.
     * @param limitUpper Transaction fails if the curve price at call time is above this
     *                   threshold. */
    function harvest(
        address base,
        address quote,
        uint256 poolIdx,
        int24 bidTick,
        int24 askTick,
        address lpConduit,
        uint128 limitLower,
        uint128 limitHigher
    ) internal returns (int128, int128) {
        PoolSpecs.PoolCursor memory pool = queryPool(base, quote, poolIdx);

        // On permissioned pools harvests are treated like a special case burn
        // with 0 liquidity. Note that unlike a true 0 burn, ambient liquidity will still
        // be returned, so oracles should handle 0 as special case if that's an issue.
        verifyPermitBurn(pool, base, quote, bidTick, askTick, 0);

        return harvestOverPool(bidTick, askTick, pool, limitLower, limitHigher, lpConduit);
    }

    /* @notice Mints ambient liquidity that's active at every price.
     * @param base The base-side token in the pair.
     * @param quote The quote-side token in the par.
     * @param poolIdx The index of the pool type being minted on.
     * @param liq The total amount of liquidity being minted. Represented as sqrt(X*Y)
     *            for the equivalent constant-product AMM.
     @ @param lpConduit The address of the LP conduit to deposit the minted position at
     *                  (direct owned liquidity if 0)
     * @param limitLower Exists to make sure the user is happy with the price the 
     *                   liquidity is minted at. Transaction fails if the curve price
     *                   at call time is below this value.
     * @param limitUpper Transaction fails if the curve price at call time is above this
     *                   threshold.  */
    function mintAmbientLiq(
        address base,
        address quote,
        uint256 poolIdx,
        uint128 liq,
        address lpConduit,
        uint128 limitLower,
        uint128 limitHigher
    ) internal returns (int128, int128) {
        PoolSpecs.PoolCursor memory pool = queryPool(base, quote, poolIdx);
        verifyPermitMint(pool, base, quote, 0, 0, liq);
        return mintOverPool(liq, pool, limitLower, limitHigher, lpConduit);
    }

    function mintAmbientQty(
        address base,
        address quote,
        uint256 poolIdx,
        bool inBase,
        uint128 qty,
        address lpConduit,
        uint128 limitLower,
        uint128 limitHigher
    ) internal returns (int128, int128) {
        bytes32 poolKey = PoolSpecs.encodeKey(base, quote, poolIdx);
        CurveMath.CurveState memory curve = snapCurve(poolKey);
        uint128 liq = Chaining.sizeAmbientLiq(qty, true, curve.priceRoot_, inBase);

        (int128 baseFlow, int128 quoteFlow) =
            mintAmbientLiq(base, quote, poolIdx, liq, lpConduit, limitLower, limitHigher);
        return Chaining.pinFlow(baseFlow, quoteFlow, qty, inBase);
    }

    function mintConcentratedQty(
        address base,
        address quote,
        uint256 poolIdx,
        int24 bidTick,
        int24 askTick,
        bool inBase,
        uint128 qty,
        address lpConduit,
        uint128 limitLower,
        uint128 limitHigher
    ) internal returns (int128, int128) {
        uint128 liq = sizeAddLiq(base, quote, poolIdx, qty, bidTick, askTick, inBase);
        (int128 baseFlow, int128 quoteFlow) =
            mintConcentratedLiq(base, quote, poolIdx, bidTick, askTick, liq, lpConduit, limitLower, limitHigher);
        return Chaining.pinFlow(baseFlow, quoteFlow, qty, inBase);
    }

    function sizeAddLiq(
        address base,
        address quote,
        uint256 poolIdx,
        uint128 qty,
        int24 bidTick,
        int24 askTick,
        bool inBase
    ) internal view returns (uint128) {
        bytes32 poolKey = PoolSpecs.encodeKey(base, quote, poolIdx);
        CurveMath.CurveState memory curve = snapCurve(poolKey);
        return Chaining.sizeConcLiq(qty, true, curve.priceRoot_, bidTick, askTick, inBase);
    }

    /* @notice Burns ambient liquidity that's active at every price.
     * @param base The base-side token in the pair.
     * @param quote The quote-side token in the par.
     * @param poolIdx The index of the pool type being burned on.
     * @param liq The total amount of liquidity being burned. Represented as sqrt(X*Y)
     *            for the equivalent constant-product AMM.
     * @param limitLower Exists to make sure the user is happy with the price the 
     *                   liquidity is burned at. Transaction fails if the curve price
     *                   at call time is below this value.
     * @param limitUpper Transaction fails if the curve price at call time is above this
     *                   threshold. */
    function burnAmbientLiq(
        address base,
        address quote,
        uint256 poolIdx,
        uint128 liq,
        address lpConduit,
        uint128 limitLower,
        uint128 limitHigher
    ) internal returns (int128, int128) {
        PoolSpecs.PoolCursor memory pool = queryPool(base, quote, poolIdx);
        verifyPermitBurn(pool, base, quote, 0, 0, liq);
        return burnOverPool(liq, pool, limitLower, limitHigher, lpConduit);
    }

    function burnAmbientQty(
        address base,
        address quote,
        uint256 poolIdx,
        bool inBase,
        uint128 qty,
        address lpConduit,
        uint128 limitLower,
        uint128 limitHigher
    ) internal returns (int128, int128) {
        bytes32 poolKey = PoolSpecs.encodeKey(base, quote, poolIdx);
        CurveMath.CurveState memory curve = snapCurve(poolKey);
        uint128 liq = Chaining.sizeAmbientLiq(qty, false, curve.priceRoot_, inBase);
        return burnAmbientLiq(base, quote, poolIdx, liq, lpConduit, limitLower, limitHigher);
    }

    function burnConcentratedQty(
        address base,
        address quote,
        uint256 poolIdx,
        int24 bidTick,
        int24 askTick,
        bool inBase,
        uint128 qty,
        address lpConduit,
        uint128 limitLower,
        uint128 limitHigher
    ) internal returns (int128, int128) {
        bytes32 poolKey = PoolSpecs.encodeKey(base, quote, poolIdx);
        CurveMath.CurveState memory curve = snapCurve(poolKey);
        uint128 liq = Chaining.sizeConcLiq(qty, false, curve.priceRoot_, bidTick, askTick, inBase);
        return burnConcentratedLiq(base, quote, poolIdx, bidTick, askTick, liq, lpConduit, limitLower, limitHigher);
    }

    /* @notice Used at upgrade time to verify that the contract is a valid Croc sidecar proxy and used
     *         in the correct slot. */
    function acceptCrocProxyRole(address, uint16 slot) public pure returns (bool) {
        return slot == CrocSlots.LP_PROXY_IDX;
    }
}

/* @title Hot path mixin.
 * @notice Provides the top-level function for the most common operation: simple one-hop
 *         swap on a single pool in the most gas optimized way. Unlike the other call 
 *         paths this should be imported directly into the main contract.
 * 
 * @dev    Unlike the other callpath sidecars this contains the most gas sensitive and
 *         common operation: a simple swap. We want to keep this the lowest gas spend
 *         possible, and therefore avoid an external DELEGATECALL. Therefore this logic
 *         is inherited both directly by the main contract (allowing for low gas calls)
 *         as well as an explicit proxy contract (allowing for future upgradeability)
 *         which can be utilized through a different call path. */
contract HotPath is MarketSequencer, SettleLayer, ProtocolAccount {
    using SafeCast for uint128;
    using TokenFlow for TokenFlow.PairSeq;
    using CurveMath for CurveMath.CurveState;
    using Chaining for Chaining.PairFlow;

    /* @notice Executes a swap on an arbitrary pool. */
    function swapExecute(
        address base,
        address quote,
        uint256 poolIdx,
        bool isBuy,
        bool inBaseQty,
        uint128 qty,
        uint16 poolTip,
        uint128 limitPrice,
        uint128 minOutput,
        uint8 reserveFlags
    ) internal returns (int128 baseFlow, int128 quoteFlow) {
        PoolSpecs.PoolCursor memory pool = preparePoolCntx(base, quote, poolIdx, poolTip, isBuy, inBaseQty, qty);

        Chaining.PairFlow memory flow = swapDir(pool, isBuy, inBaseQty, qty, limitPrice);
        (baseFlow, quoteFlow) = (flow.baseFlow_, flow.quoteFlow_);

        pivotOutFlow(flow, minOutput, isBuy, inBaseQty);
        settleFlows(base, quote, flow.baseFlow_, flow.quoteFlow_, reserveFlags);
        accumProtocolFees(flow, base, quote);
    }

    /* @notice Final check at swap completion to verify that the non-fixed side of the 
     *         swap meets the user's minimum execution standards: minimum floor if output,
     *         maximum ceiling if input. 
     * @param flow The resulting final token flows from the swap
     * @param minOutput The minimum output (if sell-side token is fixed) *or* maximum inout
     *                  (if buy-side token is fixed)
     * @param isBuy  If true indicates the swap was a buy, i.e. paid base tokens to receive
     *               quote tokens
     * @param inBaseQty If true indicates the base-side was the fixed leg of the swap.
     * @return outFlow Returns the non-fixed side of the swap flow. */
    function pivotOutFlow(Chaining.PairFlow memory flow, uint128 minOutput, bool isBuy, bool inBaseQty)
        private
        pure
        returns (int128 outFlow)
    {
        outFlow = inBaseQty ? flow.quoteFlow_ : flow.baseFlow_;
        bool isOutPaid = (isBuy == inBaseQty);
        int128 thresh = isOutPaid ? -int128(minOutput) : int128(minOutput);
        require(outFlow <= thresh || minOutput == 0, "SL");
    }

    /* @notice Wrapper call to setup the swap directive object and call the swap logic in
     *         the MarketSequencer mixin. */
    function swapDir(PoolSpecs.PoolCursor memory pool, bool isBuy, bool inBaseQty, uint128 qty, uint128 limitPrice)
        private
        returns (Chaining.PairFlow memory)
    {
        Directives.SwapDirective memory dir;
        dir.isBuy_ = isBuy;
        dir.inBaseQty_ = inBaseQty;
        dir.qty_ = qty;
        dir.limitPrice_ = limitPrice;
        dir.rollType_ = 0;
        return swapOverPool(dir, pool);
    }

    /* @notice Given a pair and pool type index queries and returns the current specs for
     *         that pool. And if permissioned pool, checks against the permit oracle, 
     *         adjusting fee if necessary. */
    function preparePoolCntx(
        address base,
        address quote,
        uint256 poolIdx,
        uint16 poolTip,
        bool isBuy,
        bool inBaseQty,
        uint128 qty
    ) private returns (PoolSpecs.PoolCursor memory) {
        PoolSpecs.PoolCursor memory pool = queryPool(base, quote, poolIdx);
        if (poolTip > pool.head_.feeRate_) {
            pool.head_.feeRate_ = poolTip;
        }
        verifyPermitSwap(pool, base, quote, isBuy, inBaseQty, qty);
        return pool;
    }

    /* @notice Syntatic sugar that wraps a swapExecute call with an ABI encoded version of
     *         the arguments. */
    function swapEncoded(bytes calldata input) internal returns (int128 baseFlow, int128 quoteFlow) {
        (
            address base,
            address quote,
            uint256 poolIdx,
            bool isBuy,
            bool inBaseQty,
            uint128 qty,
            uint16 poolTip,
            uint128 limitPrice,
            uint128 minOutput,
            uint8 reserveFlags
        ) = abi.decode(input, (address, address, uint256, bool, bool, uint128, uint16, uint128, uint128, uint8));

        return swapExecute(base, quote, poolIdx, isBuy, inBaseQty, qty, poolTip, limitPrice, minOutput, reserveFlags);
    }
}

/* @title Hot path proxy contract
 * @notice The version of the HotPath in a standalone sidecar proxy contract. If used
 *         this contract would be attached to hotProxy_ in the main dex contract. */
contract HotProxy is HotPath {
    function userCmd(bytes calldata input) public payable returns (int128, int128) {
        require(!hotPathOpen_, "Hot path enabled");
        return swapEncoded(input);
    }

    /* @notice Used at upgrade time to verify that the contract is a valid Croc sidecar proxy and used
     *         in the correct slot. */
    function acceptCrocProxyRole(address, uint16 slot) public pure returns (bool) {
        return slot == CrocSlots.SWAP_PROXY_IDX;
    }
}

/* @title Long path callpath sidecar.
 * @notice Defines a proxy sidecar contract that's used to move code outside the 
 *         main contract to avoid Ethereum's contract code size limit. Contains
 *         top-level logic for parsing and executing arbitrarily long compound orders.
 * 
 * @dev    This exists as a standalone contract but will only ever contain proxy code,
 *         not state. As such it should never be called directly or externally, and should
 *         only be invoked with DELEGATECALL so that it operates on the contract state
 *         within the primary CrocSwap contract. */
contract LongPath is MarketSequencer, SettleLayer, ProtocolAccount {
    using SafeCast for uint128;
    using TokenFlow for TokenFlow.PairSeq;
    using CurveMath for CurveMath.CurveState;
    using Chaining for Chaining.PairFlow;

    /* @notice Executes the user-defined compound order, constitutiin an arbitrary
     *         combination of mints, burns and swaps across an arbitrary set of pools
     *         across an arbitrary set of pairs.
     *
     * @param input  The encoded byte data associated with the user's order directive. See
     *               Encoding.sol and Directives.sol library for information on how to encode
     *               order directives as byte data. 
     * @return The signed token flows associated with each successive token leg in the flows.
     *         Negative indicates pool is paying user, positive pool is collecting from user. */
    function userCmd(bytes calldata input) public payable returns (int128[] memory) {
        Directives.OrderDirective memory order = OrderEncoding.decodeOrder(input);
        Directives.SettlementChannel memory settleChannel = order.open_;
        TokenFlow.PairSeq memory pairs;
        Chaining.ExecCntx memory cntx;
        int128[] memory flows = new int128[](order.hops_.length+1);

        for (uint256 i = 0; i < order.hops_.length; ++i) {
            pairs.nextHop(settleChannel.token_, order.hops_[i].settle_.token_);
            cntx.improve_ = queryPriceImprove(order.hops_[i].improve_, pairs.baseToken_, pairs.quoteToken_);

            for (uint256 j = 0; j < order.hops_[i].pools_.length; ++j) {
                Directives.PoolDirective memory dir = order.hops_[i].pools_[j];
                cntx.pool_ = queryPool(pairs.baseToken_, pairs.quoteToken_, dir.poolIdx_);

                verifyPermit(cntx.pool_, pairs.baseToken_, pairs.quoteToken_, dir.ambient_, dir.swap_, dir.conc_);
                cntx.roll_ = targetRoll(dir.chain_, pairs);

                tradeOverPool(pairs.flow_, dir, cntx);
            }

            accumProtocolFees(pairs); // Make sure to call before clipping
            flows[i] = pairs.clipFlow();
            settleChannel = order.hops_[i].settle_;
        }

        flows[order.hops_.length] = pairs.closeFlow();
        settleFlows(order, flows);
        return flows;
    }

    function settleFlows(Directives.OrderDirective memory order, int128[] memory flows) internal {
        Directives.SettlementChannel memory settleChannel = order.open_;
        int128 ethFlow = 0;

        for (uint256 i = 0; i < order.hops_.length; ++i) {
            ethFlow += settleLeg(flows[i], settleChannel);
            settleChannel = order.hops_[i].settle_;
        }
        settleFinal(flows[order.hops_.length], settleChannel, ethFlow);
    }

    /* @notice Sets the roll target parameters based on the user's directive and the
     *         previously accumulated flow on the pair.
     * @param flags The user specified chaining directive for this pair.
     * @param pair The hitherto accumulated flows on the pair. 
     * @return roll The rolling back fill context to be used in any back-fill quantity. */
    function targetRoll(Directives.ChainingFlags memory flags, TokenFlow.PairSeq memory pair)
        private
        view
        returns (Chaining.RollTarget memory roll)
    {
        if (flags.rollExit_) {
            roll.inBaseQty_ = !pair.isBaseFront_;
            roll.prePairBal_ = 0;
        } else {
            roll.inBaseQty_ = pair.isBaseFront_;
            roll.prePairBal_ = pair.legFlow_;
        }

        if (flags.offsetSurplus_) {
            address token = flags.rollExit_ ? pair.backToken() : pair.frontToken();
            roll.prePairBal_ -= querySurplus(lockHolder_, token).toInt128Sign();
        }
    }

    /* @notice Used at upgrade time to verify that the contract is a valid Croc sidecar proxy and used
     *         in the correct slot. */
    function acceptCrocProxyRole(address, uint16 slot) public pure returns (bool) {
        return slot == CrocSlots.LONG_PROXY_IDX;
    }
}

/* @title Knockout Flag Proxy
 * @notice This is an internal library callpath that's called when a swap triggers a 
 *         knockout liquidity event by crossing a given bump point. 
 * @dev It exists as a separate callpath from the normal swap() code path because crossing
 *      a knockout pivot is a relatively rare event and the code won't fully fit into the
 *      hot path contract. */
contract KnockoutFlagPath is KnockoutCounter {
    /* @notice Called when a knockout pivot is crossed.
     *
     * @dev Since this contract is a proxy sidecar, this method needs to be marked
     *      payable even though it doesn't directly handle msg.value. Otherwise it will
     *      fail on any. Because of this, this contract should never be used in any other
     *      context besides a proxy sidecar to CrocSwapDex.
     *
     * @param pool The hash index of the pool.
     * @param tick The 24-bit index of the tick where the knockout pivot exists.
     * @param isBuy If true indicates that the swap direction is a buy.
     * @param feeGlobal The global fee odometer for 1 hypothetical unit of liquidity fully
     *                  in range since the inception of the pool.
     *
     * @return Returns the net additional amount the curve liquidity should be adjusted by.
     *         Currently this always returns zero, because a liquidity knockout will never change
     *         active liquidity on a curve. But by leaving this function return type it leaves open
     *         the possibility in future upgrades of alternative types of dynamic liquidity that 
     *         do change active curve liquidity when crossed */
    function crossCurveFlag(bytes32 pool, int24 tick, bool isBuy, uint64 feeGlobal) public payable returns (int128) {
        // If swap is a sell, then implies we're crossing a resting bid and vice versa
        bool bidCross = !isBuy;
        crossKnockout(pool, bidCross, tick, feeGlobal);
        return 0;
    }

    /* @notice Used at upgrade time to verify that the contract is a valid Croc sidecar proxy and used
     *         in the correct slot. */
    function acceptCrocProxyRole(address, uint16 slot) public pure returns (bool) {
        return slot == CrocSlots.FLAG_CROSS_PROXY_IDX;
    }
}

/* @title Knockout Liquidity Proxy
 * @notice This callpath is a single point of entry for all LP operations related to 
 *         resting knockout liquidity. Including minting, burning, claiming, and 
 *         recovering a user's posted knockout liquidity. */
contract KnockoutLiqPath is TradeMatcher, SettleLayer {
    using SafeCast for uint128;
    using TickMath for uint128;
    using TokenFlow for TokenFlow.PairSeq;
    using CurveMath for CurveMath.CurveState;
    using Chaining for Chaining.PairFlow;
    using KnockoutLiq for KnockoutLiq.KnockoutPosLoc;

    function userCmd(bytes calldata cmd) public payable returns (int128 baseFlow, int128 quoteFlow) {
        (
            uint8 code,
            address base,
            address quote,
            uint256 poolIdx,
            int24 bidTick,
            int24 askTick,
            bool isBid,
            uint8 reserveFlags,
            bytes memory args
        ) = abi.decode(cmd, (uint8, address, address, uint256, int24, int24, bool, uint8, bytes));

        PoolSpecs.PoolCursor memory pool = queryPool(base, quote, poolIdx);
        CurveMath.CurveState memory curve = snapCurve(pool.hash_);

        KnockoutLiq.KnockoutPosLoc memory loc;
        loc.isBid_ = isBid;
        loc.lowerTick_ = bidTick;
        loc.upperTick_ = askTick;

        return overCurve(code, base, quote, pool, curve, loc, reserveFlags, args);
    }

    /* @notice Converts a call code, pool address, curvedata and knockout position 
     *         location to execute a knockout LP command. */
    function overCurve(
        uint8 code,
        address base,
        address quote,
        PoolSpecs.PoolCursor memory pool,
        CurveMath.CurveState memory curve,
        KnockoutLiq.KnockoutPosLoc memory loc,
        uint8 reserveFlags,
        bytes memory args
    ) private returns (int128 baseFlow, int128 quoteFlow) {
        if (code == UserCmd.MINT_KNOCKOUT) {
            (baseFlow, quoteFlow) = mintCmd(base, quote, pool, curve, loc, args);
        } else if (code == UserCmd.BURN_KNOCKOUT) {
            (baseFlow, quoteFlow) = burnCmd(base, quote, pool, curve, loc, args);
        } else if (code == UserCmd.CLAIM_KNOCKOUT) {
            (baseFlow, quoteFlow) = claimCmd(pool.hash_, curve, loc, args);
        } else if (code == UserCmd.RECOVER_KNOCKOUT) {
            (baseFlow, quoteFlow) = recoverCmd(pool.hash_, loc, args);
        } else {
            revert("Invalid command");
        }

        settleFlows(base, quote, baseFlow, quoteFlow, reserveFlags);
    }

    /* @notice Mints new passive knockout liquidity. */
    function mintCmd(
        address base,
        address quote,
        PoolSpecs.PoolCursor memory pool,
        CurveMath.CurveState memory curve,
        KnockoutLiq.KnockoutPosLoc memory loc,
        bytes memory args
    ) private returns (int128 baseFlow, int128 quoteFlow) {
        (uint128 qty, bool insideMid) = abi.decode(args, (uint128, bool));

        int24 priceTick = curve.priceRoot_.getTickAtSqrtRatio();
        require(loc.spreadOkay(priceTick, insideMid), "KL");

        uint128 liq = Chaining.sizeConcLiq(qty, true, curve.priceRoot_, loc.lowerTick_, loc.upperTick_, loc.isBid_);
        verifyPermitMint(pool, base, quote, loc.lowerTick_, loc.upperTick_, liq);

        (baseFlow, quoteFlow) = mintKnockout(curve, priceTick, loc, liq, pool.hash_, pool.head_.knockoutBits_);
        commitCurve(pool.hash_, curve);
        (baseFlow, quoteFlow) = Chaining.pinFlow(baseFlow, quoteFlow, qty, loc.isBid_);
    }

    /* @notice Burns previously minted knockout liquidity, but only applicable to the
     *         extent that the position hasn't been fully knocked out. */
    function burnCmd(
        address base,
        address quote,
        PoolSpecs.PoolCursor memory pool,
        CurveMath.CurveState memory curve,
        KnockoutLiq.KnockoutPosLoc memory loc,
        bytes memory args
    ) private returns (int128 baseFlow, int128 quoteFlow) {
        (uint128 qty, bool inLiqQty, bool insideMid) = abi.decode(args, (uint128, bool, bool));

        int24 priceTick = curve.priceRoot_.getTickAtSqrtRatio();
        require(loc.spreadOkay(priceTick, insideMid), "KL");

        uint128 liq = inLiqQty
            ? qty
            : Chaining.sizeConcLiq(qty, false, curve.priceRoot_, loc.lowerTick_, loc.upperTick_, loc.isBid_);
        verifyPermitBurn(pool, base, quote, loc.lowerTick_, loc.upperTick_, liq);

        (baseFlow, quoteFlow) = burnKnockout(curve, priceTick, loc, liq, pool.hash_);
        commitCurve(pool.hash_, curve);
    }

    /* @notice Claims a knockout liquidity position that has been fully knocked out, 
     *         including the earned liquidity fees. 
     * @param pool The pool index.
     * @param curve The current state of the AMM curve.
     * @param loc The location the knockout liquidity is being claimed from
     * @params args Corresponds to the Merkle proof for the knockout point ABI encoded
     *              into two components:
     *                 root - The current root of the Merkle chain for the pivot location
     *                 proof - The accumulated links in the Merkle chain going back to the
     *                         point the user's pivot was knocked out. */
    function claimCmd(
        bytes32 pool,
        CurveMath.CurveState memory curve,
        KnockoutLiq.KnockoutPosLoc memory loc,
        bytes memory args
    ) private returns (int128 baseFlow, int128 quoteFlow) {
        (uint160 root, uint256[] memory proof) = abi.decode(args, (uint160, uint256[]));

        // No permit check because permit oracles do not control knockout claims
        // (See ICrocPermitOracle for more information)
        (baseFlow, quoteFlow) = claimKnockout(curve, loc, root, proof, pool);
        commitCurve(pool, curve);
    }

    /* @notice Like claim, but ignores the Merkle proof (either because the user wants to
     *         avoid the gas cost or isn't bothered to recover the history). This results
     *         in the earned liquidity fees being forfeit, but the user still recovers the
     *         full principal of the underlying order.
     *
     * @param pool The pool index.
     * @param loc The location the knockout liquidity is being claimed from
     * @params args Corresponds to a flat ABI encoding of the pivot's origin in block 
     *              time. 
     * @return baseFlow The total base token flow from the pool to the user
     * @return quoteFlow The total base token flow from the pool to the user */
    function recoverCmd(bytes32 pool, KnockoutLiq.KnockoutPosLoc memory loc, bytes memory args)
        private
        returns (int128 baseFlow, int128 quoteFlow)
    {
        (uint32 pivotTime) = abi.decode(args, (uint32));

        // No permit check because permit oracles do not control knockout claims
        // (See ICrocPermitOracle for more information)

        (baseFlow, quoteFlow) = recoverKnockout(loc, pivotTime, pool);
        // No need to commit curve because recover doesn't touch curve.
    }

    /* @notice Used at upgrade time to verify that the contract is a valid Croc sidecar proxy and used
     *         in the correct slot. */
    function acceptCrocProxyRole(address, uint16 slot) public pure returns (bool) {
        return slot == CrocSlots.KNOCKOUT_LP_PROXY_IDX;
    }
}

/* @title Micro paths callpath sidecar.
 * @notice Defines a proxy sidecar contract that's used to move code outside the 
 *         main contract to avoid Ethereum's contract code size limit. Contains
 *         mid-level components related to single atomic actions to be called within the
 *         context of a longer compound action on a pre-loaded pool's liquidity curve.
 * 
 * @dev    This exists as a standalone contract but will only ever contain proxy code,
 *         not state. As such it should never be called directly or externally, and should
 *         only be invoked with DELEGATECALL so that it operates on the contract state
 *         within the primary CrocSwap contract. */
contract MicroPaths is MarketSequencer {
    /* @notice Burns liquidity on a concentrated range position within a single curve.
     *
     * @param price The price of the curve. Represented as the square root of the exchange
     *              rate in Q64.64 fixed point
     * @param priceTick The price tick index of the current price of the curve
     * @param seed The ambient liquidity seeds in the current curve.
     * @param conc The active in-range concentrated liquidity in the current curve.
     * @param seedGrowth The cumulative ambient seed deflator in the current curve.
     * @param concGrowth The cumulative concentrated reward growth on the current curve.
     * @param lowTick The price tick index of the lower barrier.
     * @param highTick The price tick index of the upper barrier.
     * @param liq The amount of liquidity to burn.
     * @param poolHash The key hash of the pool the curve belongs to.
     *
     * @return baseFlow The user<->pool flow on the base-side token associated with the 
     *                  action. Negative implies flow from the pool to the user. Positive
     *                  vice versa.
     * @return quoteFlow The user<->pool flow on the quote-side token associated with the 
     *                   action. 
     * @return seedOut The updated ambient seed liquidity on the curve.
     * @return concOut The updated concentrated liquidity on the curve. */
    function burnRange(
        uint128 price,
        int24 priceTick,
        uint128 seed,
        uint128 conc,
        uint64 seedGrowth,
        uint64 concGrowth,
        int24 lowTick,
        int24 highTick,
        uint128 liq,
        bytes32 poolHash
    ) public payable returns (int128 baseFlow, int128 quoteFlow, uint128 seedOut, uint128 concOut) {
        CurveMath.CurveState memory curve;
        curve.priceRoot_ = price;
        curve.ambientSeeds_ = seed;
        curve.concLiq_ = conc;
        curve.seedDeflator_ = seedGrowth;
        curve.concGrowth_ = concGrowth;

        (baseFlow, quoteFlow) = burnRange(curve, priceTick, lowTick, highTick, liq, poolHash, lockHolder_);

        concOut = curve.concLiq_;
        seedOut = curve.ambientSeeds_;
    }

    /* @notice Mints liquidity on a concentrated range position within a single curve.
     *
     * @param price The price of the curve. Represented as the square root of the exchange
     *              rate in Q64.64 fixed point
     * @param priceTick The price tick index of the current price of the curve
     * @param seed The ambient liquidity seeds in the current curve.
     * @param conc The active in-range concentrated liquidity in the current curve.
     * @param seedGrowth The cumulative ambient seed deflator in the current curve.
     * @param concGrowth The cumulative concentrated reward growth on the current curve.
     * @param lowTick The price tick index of the lower barrier.
     * @param highTick The price tick index of the upper barrier.
     * @param liq The amount of liquidity to mint.
     * @param poolHash The key hash of the pool the curve belongs to.
     *
     * @return baseFlow The user<->pool flow on the base-side token associated with the 
     *                  action. Negative implies flow from the pool to the user. Positive
     *                  vice versa.
     * @return quoteFlow The user<->pool flow on the quote-side token associated with the 
     *                   action. 
     * @return seedOut The updated ambient seed liquidity on the curve.
     * @return concOut The updated concentrated liquidity on the curve. */
    function mintRange(
        uint128 price,
        int24 priceTick,
        uint128 seed,
        uint128 conc,
        uint64 seedGrowth,
        uint64 concGrowth,
        int24 lowTick,
        int24 highTick,
        uint128 liq,
        bytes32 poolHash
    ) public payable returns (int128 baseFlow, int128 quoteFlow, uint128 seedOut, uint128 concOut) {
        CurveMath.CurveState memory curve;
        curve.priceRoot_ = price;
        curve.ambientSeeds_ = seed;
        curve.concLiq_ = conc;
        curve.seedDeflator_ = seedGrowth;
        curve.concGrowth_ = concGrowth;

        (baseFlow, quoteFlow) = mintRange(curve, priceTick, lowTick, highTick, liq, poolHash, lockHolder_);

        concOut = curve.concLiq_;
        seedOut = curve.ambientSeeds_;
    }

    /* @notice Burns liquidity from an ambient liquidity position on a single curve.
     *
     * @param price The price of the curve. Represented as the square root of the exchange
     *              rate in Q64.64 fixed point
     * @param seed The ambient liquidity seeds in the current curve.
     * @param conc The active in-range concentrated liquidity in the current curve.
     * @param seedGrowth The cumulative ambient seed deflator in the current curve.
     * @param concGrowth The cumulative concentrated reward growth on the current curve.
     * @param liq The amount of liquidity to burn.
     * @param poolHash The key hash of the pool the curve belongs to.
     *
     * @return baseFlow The user<->pool flow on the base-side token associated with the 
     *                  action. Negative implies flow from the pool to the user. Positive
     *                  vice versa.
     * @return quoteFlow The user<->pool flow on the quote-side token associated with the 
     *                   action. 
     * @return seedOut The updated ambient seed liquidity on the curve. */
    function burnAmbient(
        uint128 price,
        uint128 seed,
        uint128 conc,
        uint64 seedGrowth,
        uint64 concGrowth,
        uint128 liq,
        bytes32 poolHash
    ) public payable returns (int128 baseFlow, int128 quoteFlow, uint128 seedOut) {
        CurveMath.CurveState memory curve;
        curve.priceRoot_ = price;
        curve.ambientSeeds_ = seed;
        curve.concLiq_ = conc;
        curve.seedDeflator_ = seedGrowth;
        curve.concGrowth_ = concGrowth;

        (baseFlow, quoteFlow) = burnAmbient(curve, liq, poolHash, lockHolder_);

        seedOut = curve.ambientSeeds_;
    }

    /* @notice Mints liquidity from an ambient liquidity position on a single curve.
     *
     * @param price The price of the curve. Represented as the square root of the exchange
     *              rate in Q64.64 fixed point
     * @param seed The ambient liquidity seeds in the current curve.
     * @param conc The active in-range concentrated liquidity in the current curve.
     * @param seedGrowth The cumulative ambient seed deflator in the current curve.
     * @param concGrowth The cumulative concentrated reward growth on the current curve.
     * @param liq The amount of liquidity to mint.
     * @param poolHash The key hash of the pool the curve belongs to.
     *
     * @return baseFlow The user<->pool flow on the base-side token associated with the 
     *                  action. Negative implies flow from the pool to the user. Positive
     *                  vice versa.
     * @return quoteFlow The user<->pool flow on the quote-side token associated with the 
     *                   action. 
     * @return seedOut The updated ambient seed liquidity on the curve. */
    function mintAmbient(
        uint128 price,
        uint128 seed,
        uint128 conc,
        uint64 seedGrowth,
        uint64 concGrowth,
        uint128 liq,
        bytes32 poolHash
    ) public payable returns (int128 baseFlow, int128 quoteFlow, uint128 seedOut) {
        CurveMath.CurveState memory curve;
        curve.priceRoot_ = price;
        curve.ambientSeeds_ = seed;
        curve.concLiq_ = conc;
        curve.seedDeflator_ = seedGrowth;
        curve.concGrowth_ = concGrowth;

        (baseFlow, quoteFlow) = mintAmbient(curve, liq, poolHash, lockHolder_);

        seedOut = curve.ambientSeeds_;
    }

    /* @notice Executes a user-directed swap through a single liquidity curve.
     * 
     * @param curve The current state of the liquidity curve.
     * @param midTick The tick index of the current price of the curve.
     * @param swap The parameters of the swap to be executed.
     * @param pool The pre-loaded specification and hash key of the liquidity curve's
     *             pool.
     *
     * @return accum The accumulated flows on the pair associated with the swap.
     * @return priceOut The price of the curve after the swap completes. Represented as
     *                  the square root of the price in Q64.64 fixed point.
     * @return seedOut The ambient liquidity seeds in the curve after the swap completes
     * @return concOut The active in-range concentrated liquidity in the curve post-swap
     * @return ambientOut The cumulative ambient seed deflator on the curve post-swap.
     * @return concGrowthOut The cumulative concentrated rewards growth on the curve 
     *                       post-swap. */
    function sweepSwap(
        CurveMath.CurveState memory curve,
        int24 midTick,
        Directives.SwapDirective memory swap,
        PoolSpecs.PoolCursor memory pool
    )
        public
        payable
        returns (
            Chaining.PairFlow memory accum,
            uint128 priceOut,
            uint128 seedOut,
            uint128 concOut,
            uint64 ambientOut,
            uint64 concGrowthOut
        )
    {
        sweepSwapLiq(accum, curve, midTick, swap, pool);

        priceOut = curve.priceRoot_;
        seedOut = curve.ambientSeeds_;
        concOut = curve.concLiq_;
        ambientOut = curve.seedDeflator_;
        concGrowthOut = curve.concGrowth_;
    }

    /* @notice Used at upgrade time to verify that the contract is a valid Croc sidecar proxy and used
     *         in the correct slot. */
    function acceptCrocProxyRole(address, uint16 slot) public pure returns (bool) {
        return slot == CrocSlots.MICRO_PROXY_IDX;
    }
}

/* @title Safe Mode Call Path.
 *
 * @notice Highly restricted callpath meant to be the sole point of entry when the dex
 *         contract has been forced into emergency safe mode. Essentially this retricts 
 *         all calls besides sudo mode admin actions. */
contract SafeModePath is ColdPath {
    function protocolCmd(bytes calldata cmd) public override {
        sudoCmd(cmd);
    }

    function userCmd(bytes calldata) public payable override {
        revert("Emergency Safe Mode");
    }

    /* @notice Used at upgrade time to verify that the contract is a valid Croc sidecar proxy and used
     *         in the correct slot. */
    function acceptCrocProxyRole(address, uint16 slot) public pure override returns (bool) {
        return slot == CrocSlots.SAFE_MODE_PROXY_PATH;
    }
}

/* @title CrocSwap exchange contract
 * @notice Top-level CrocSwap contract. Contains all public facing methods and state
 *         for the entire dex across every pool.
 *
 * @dev    Sidecar proxy contracts exist to contain code that doesn't fit in the Ethereum
 *         limit, but this is the only contract that users need to directly interface 
 *         with. */
contract CrocSwapDex is HotPath, ICrocMinion {
    using SafeCast for uint128;
    using TokenFlow for TokenFlow.PairSeq;
    using CurveMath for CurveMath.CurveState;
    using Chaining for Chaining.PairFlow;

    constructor() {
        // Authority is originally set to deployer address, which can then transfer to
        // proper governance contract (if deployer already isn't)
        authority_ = msg.sender;
        hotPathOpen_ = true;
        proxyPaths_[CrocSlots.BOOT_PROXY_IDX] = address(new BootPath());
    }

    /* @notice Swaps between two tokens within a single liquidity pool.
     *
     * @dev This is the most gas optimized swap call, since it avoids calling out to any
     *      proxy contract. However there's a possibility in the future that this call 
     *      path could be disabled to support upgraded logic. In which case the caller 
     *      should be able to swap through using a userCmd() call on the HOT_PATH proxy
     *      call path.
     * 
     * @param base The base-side token of the pair. (For native Ethereum use 0x0)
     * @param quote The quote-side token of the pair.
     * @param poolIdx The index of the pool type to execute on.
     * @param isBuy If true the direction of the swap is for the user to send base tokens
     *              and receive back quote tokens.
     * @param inBaseQty If true the quantity is denominated in base-side tokens. If not
     *                  use quote-side tokens.
     * @param qty The quantity of tokens to swap. End result could be less if the pool 
     *            price reaches limitPrice before exhausting.
     * @param tip A user-designated liquidity fee paid to the LPs in the pool. If set to
     *            0, just defaults to the standard pool rate. Otherwise represents the
     *            proposed LP fee in units of 1/1,000,000. Not used in standard swap 
     *            calls, but may be used in certain permissioned or dynamic fee pools.
     * @param limitPrice The worse price the user is willing to pay on the margin. Swap
     *                   will execute up to this price, but not any worse. Average fill 
     *                   price will always be equal or better, because this is calculated
     *                   at the marginal unit of quantity.
     * @param minOut The minimum output the user expects from the swap. If less is 
     *               returned, the transaction will revert. (Alternatively if the swap
     *               is fixed in terms of output, this is the maximum input.)
     * @param reserveFlags Bitwise flags to indicate if the user wants to pay/receive in
     *                     terms of surplus collateral balance held at the dex contract.
     *                          0x1 - Base token is paid/received from surplus collateral
     *                          0x2 - Quote token is paid/received from surplus collateral
     * @return The token base and quote token flows associated with this swap action. 
     *         (Negative indicates a credit paid to the user, positive a debit collected
     *         from the user) */
    function swap(
        address base,
        address quote,
        uint256 poolIdx,
        bool isBuy,
        bool inBaseQty,
        uint128 qty,
        uint16 tip,
        uint128 limitPrice,
        uint128 minOut,
        uint8 reserveFlags
    ) public payable reEntrantLock returns (int128 baseQuote, int128 quoteFlow) {
        // By default the embedded hot-path is enabled, but protocol governance can
        // disable by toggling the force proxy flag. If so, users should point to
        // swapProxy.
        require(hotPathOpen_);
        return swapExecute(base, quote, poolIdx, isBuy, inBaseQty, qty, tip, limitPrice, minOut, reserveFlags);
    }

    /* @notice Consolidated method for protocol control related commands.
     * @dev    We consolidate multiple protocol control types into a single method to 
     *         reduce the contract size in the main contract by paring down methods.
     * 
     * @param callpath The proxy sidecar callpath called into. (Calls into proxyCmd() on
     *                 the respective sidecare contract)
     * @param cmd      The arbitrary byte calldata corresponding to the command. Format
     *                 dependent on the specific callpath.
     * @param sudo     If true, indicates that the command should be called with elevated
     *                 privileges. */
    function protocolCmd(uint16 callpath, bytes calldata cmd, bool sudo) public payable override protocolOnly(sudo) {
        callProtocolCmd(callpath, cmd);
    }

    /* @notice Calls an arbitrary command on one of the sidecar proxy contracts at a specific
     *         index. Not all proxy slots may have a contract attached. If so, this call will
     *         fail.
     *
     * @param callpath The index of the proxy sidecar the command is being called on.
     * @param cmd The arbitrary call data the client is calling the proxy sidecar.
     * @return Arbitrary byte data (if any) returned by the command. */
    function userCmd(uint16 callpath, bytes calldata cmd) public payable reEntrantLock returns (bytes memory) {
        return callUserCmd(callpath, cmd);
    }

    /* @notice Calls an arbitrary command on behalf of another user who has signed an 
     *         EIP-712 off-chain transaction. Same general call logic as userCmd(), but
     *         with additional args for conditions, and relayer payment.
     *
     * @param callpath The index of the proxy sidecar the command is being called on.
     * @param cmd The arbitrary call data the client is calling the proxy sidecar.
     * @param conds An ABI encoded list of evaluation conditions that are required for 
     *              this command to execute. See AgentMask.sol for format of this data.
     * @param relayerTip An ABI encoded directive for tipping the relayer on behalf of
     *                   the underlying client, for having mined the transaction. If this
     *                   byte array is empty no calldata. See AgentMask.sol for format 
     *                   details.
     * @param signature The ERC-712 signature of the above parameters signed by the 
     *                  private key of the public address the command is being executed 
     *                  for.
     * @return Arbitrary byte data (if any) returned by the command. */
    function userCmdRelayer(
        uint16 callpath,
        bytes calldata cmd,
        bytes calldata conds,
        bytes calldata relayerTip,
        bytes calldata signature
    )
        public
        payable
        reEntrantAgent(CrocRelayerCall(callpath, cmd, conds, relayerTip), signature)
        returns (bytes memory output)
    {
        output = callUserCmd(callpath, cmd);
        tipRelayer(relayerTip);
    }

    /* @notice Calls an arbitrary command on behalf of a user from a (pre-approved) 
     *         external router contract acting as an agent on the user's behalf.
     *
     * @dev This can only be called when the underlying user has previously approved the
     *      msg.sender address as a router on its behalf.
     *
     * @param callpath The index of the proxy sidecar the command is being called on.
     * @param cmd The arbitrary call data the client is calling the proxy sidecar.
     * @param client The address of the client the router is calling on behalf of.
     * @return Arbitrary byte data (if any) returned by the command. */
    function userCmdRouter(uint16 callpath, bytes calldata cmd, address client)
        public
        payable
        reEntrantApproved(client, callpath)
        returns (bytes memory)
    {
        return callUserCmd(callpath, cmd);
    }

    /* @notice General purpose query fuction for reading arbitrary data from the dex.
     * @dev    This function is bare bones, because we're trying to keep the size 
     *         footprint of CrocSwapDex down. See SlotLocations.sol and QueryHelper.sol 
     *         for syntactic sugar around accessing/parsing specific data. */
    function readSlot(uint256 slot) public view returns (uint256 data) {
        assembly {
            data := sload(slot)
        }
    }

    /* @notice Validation function used by external contracts to verify an address is
     *         a valid CrocSwapDex contract. */
    function acceptCrocDex() public pure returns (bool) {
        return true;
    }
}

/* @notice Alternative constructor to CrocSwapDex that's more convenient. However
 *     the deploy transaction is several hundred kilobytes and will get droppped by 
 *     geth. Useful for testing environments though. */
contract CrocSwapDexSeed is CrocSwapDex {
    constructor() {
        proxyPaths_[CrocSlots.LP_PROXY_IDX] = address(new WarmPath());
        proxyPaths_[CrocSlots.COLD_PROXY_IDX] = address(new ColdPath());
        proxyPaths_[CrocSlots.LONG_PROXY_IDX] = address(new LongPath());
        proxyPaths_[CrocSlots.MICRO_PROXY_IDX] = address(new MicroPaths());
        proxyPaths_[CrocSlots.FLAG_CROSS_PROXY_IDX] = address(new KnockoutFlagPath());
        proxyPaths_[CrocSlots.KNOCKOUT_LP_PROXY_IDX] = address(new KnockoutLiqPath());
        proxyPaths_[CrocSlots.SAFE_MODE_PROXY_PATH] = address(new SafeModePath());
    }
}

interface ICroc {
    function readSlot(uint256) external view returns (uint256);
}

contract QueryCroc {
    using CurveMath for CurveMath.CurveState;
    using CurveRoll for CurveMath.CurveState;
    using SwapCurve for CurveMath.CurveState;
    using SafeCast for uint144;
    using TickMath for uint128;
    using LiquidityMath for uint128;
    using Chaining for Chaining.PairFlow;
    using Bitmaps for uint256;
    using Bitmaps for int24;

    ICroc internal immutable dex;

    constructor(address _dex) {
        dex = ICroc(payable(_dex));
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
        //console2.log("slot0.currTick", int256(currTick));
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
        // lower
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
        //console2.log("crossDelta", int256(crossDelta));
        if (crossDelta != 0) {
            int256 data = int256(uint256(int256(info.bumpTick)) << 128)
                + (int256(crossDelta) & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff);
            info.res = bytes.concat(info.res, bytes32(uint256(data)));
            info.index++;
        }

        return info.isUpper ? bumpTick : bumpTick - 1;
    }

    function pinBitmap(bytes32 poolHash, bool isUpper, int24 startTick)
        internal
        view
        returns (int24 boundTick, bool isSpill)
    {
        //console2.log("startTick", int256(startTick));
        //console2.log("isUpper", isUpper);
        uint256 termBitmap = queryTerminus(encodeTerm(poolHash, startTick));
        uint16 shiftTerm = startTick.termBump(isUpper);
        int16 tickMezz = startTick.mezzKey();
        //console2.log("shiftTerm", uint256(shiftTerm));
        //console2.log("tickMezz", int256(tickMezz));
        (boundTick, isSpill) = pinTermMezz(isUpper, shiftTerm, tickMezz, termBitmap);
    }

    function pinTermMezz(bool isUpper, uint16 shiftTerm, int16 tickMezz, uint256 termBitmap)
        internal
        pure
        returns (int24 nextTick, bool spillBit)
    {
        (uint8 nextTerm, bool spillTrunc) = termBitmap.bitAfterTrunc(shiftTerm, isUpper);
        //console2.log("nextTerm", uint256(nextTerm));
        //console2.log("spillTrunc", spillTrunc);
        spillBit = doesSpillBit(isUpper, spillTrunc, termBitmap);
        //console2.log("spillBit", spillBit);
        nextTick = spillBit ? spillOverPin(isUpper, tickMezz) : Bitmaps.weldMezzTerm(tickMezz, nextTerm);
        //console2.log("nextTick", nextTick);
    }

    function spillOverPin(bool isUpper, int16 tickMezz) internal pure returns (int24) {
        if (isUpper) {
            return tickMezz == Bitmaps.zeroMezz(isUpper)
                ? Bitmaps.zeroTick(isUpper)
                : Bitmaps.weldMezzTerm(tickMezz + 1, Bitmaps.zeroTerm(!isUpper));
        } else {
            return Bitmaps.weldMezzTerm(tickMezz, 0);
        }
    }

    function doesSpillBit(bool isUpper, bool spillTrunc, uint256 termBitmap) internal pure returns (bool spillBit) {
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

    function seekOverLobby(bytes32 poolIdx, uint8 lobbyBit, bool isUpper) internal view returns (int24) {
        return isUpper ? seekLobbyUp(poolIdx, lobbyBit) : seekLobbyDown(poolIdx, lobbyBit);
    }

    function seekLobbyUp(bytes32 poolIdx, uint8 lobbyBit) internal view returns (int24) {
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

    function seekLobbyDown(bytes32 poolIdx, uint8 lobbyBit) internal view returns (int24) {
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
        internal
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
        internal
        view
        returns (int24, bool)
    {
        uint256 neighborBitmap = queryTerminus(encodeTermWord(poolIdx, lobbyBit, mezzBit));
        (uint8 termBit, bool spills) = neighborBitmap.bitAfterTrunc(0, isUpper);
        if (spills) return (0, true);
        return (Bitmaps.weldLobbyPosMezzTerm(lobbyBit, mezzBit, termBit), false);
    }

    function queryMezz(bytes32 key) internal view returns (uint256) {
        uint256 MEZZ_SLOT = 65542;
        bytes32 slot = keccak256(abi.encode(key, MEZZ_SLOT));
        uint256 res = _readSlot(slot);
        //console2.log("query Mezz", res);
        return res;
    }

    function queryTerminus(bytes32 key) internal view returns (uint256) {
        uint256 TERMINUS_SLOT = 65543;
        bytes32 slot = keccak256(abi.encode(key, TERMINUS_SLOT));
        uint256 res = _readSlot(slot);
        //console2.log("query Terminus", res);
        return res;
    }

    function queryLevel(bytes32 poolHash, int24 tick) internal view returns (uint96 bidLots, uint96 askLots) {
        bytes32 key = keccak256(abi.encodePacked(poolHash, tick));
        bytes32 slot = keccak256(abi.encode(key, CrocSlots.LVL_MAP_SLOT));
        uint256 val = _readSlot(slot);

        askLots = uint96((val << 64) >> 160);
        bidLots = uint96((val << 160) >> 160);
        // console2.log("query level tick", int256(tick));

        //console2.log("query level val", val);
    }

    function encodeTermWord(bytes32 poolIdx, uint8 lobbyPos, uint8 mezzPos) internal pure returns (bytes32) {
        int16 mezzIdx = Bitmaps.weldLobbyMezz(Bitmaps.uncastBitmapIndex(lobbyPos), mezzPos);
        return keccak256(abi.encodePacked(poolIdx, mezzIdx));
    }

    function encodeMezzWord(bytes32 poolIdx, uint8 lobbyPos) internal pure returns (bytes32) {
        return encodeMezzWord(poolIdx, Bitmaps.uncastBitmapIndex(lobbyPos));
    }

    function encodeMezzWord(bytes32 poolIdx, int8 lobbyPos) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(poolIdx, lobbyPos));
    }

    function encodeTerm(bytes32 poolIdx, int24 tick) internal pure returns (bytes32) {
        int16 wordPos = tick.mezzKey();
        return keccak256(abi.encodePacked(poolIdx, wordPos));
    }

    function encodeMezz(bytes32 poolIdx, int24 tick) internal pure returns (bytes32) {
        int8 wordPos = tick.lobbyKey();
        return keccak256(abi.encodePacked(poolIdx, wordPos));
    }

    function rootsForBorder(int24 borderTick, bool isUpper) internal pure returns (uint8 lobbyBit, uint8 mezzBit) {
        int24 pinTick = isUpper ? borderTick : (borderTick - 1);
        lobbyBit = pinTick.lobbyBit();
        mezzBit = pinTick.mezzBit();
    }
}
