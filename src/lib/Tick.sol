// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.14;

library Tick {
    struct Info {
        bool initialized;
        uint128 liquidity;
    }

    function update(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        uint128 liquidityDelta
    ) internal returns (bool flipped) {
        Tick.Info storage tickInfo = self[tick];
        uint128 liquidityBefore = tickInfo.liquidity;
        uint128 liquidityAfter = liquidityBefore + liquidityDelta;

        if (liquidityBefore == 0) {
            tickInfo.initialized = true;
        }

        tickInfo.liquidity = liquidityAfter;

        //evaluates to if there was a flip of a tick (entire liqudity is removed from a tick or liquidity was added to an empty tick)
        flipped = (liquidityAfter == 0) != (liquidityBefore == 0);
    }
}
