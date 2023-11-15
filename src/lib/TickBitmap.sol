// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {BitMath} from "src/lib/BitMath.sol";

library TickBitmap {
    function position(
        int24 tick
    ) private pure returns (int16 wordPos, uint8 bitPos) {
        wordPos = int16(tick >> 8);
        bitPos = uint8(uint24(tick % 256));
    }

    function flipTick(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing
    ) internal {
        require(tick % tickSpacing == 0);

        (int16 wordPos, uint8 bitPos) = position(tick / tickSpacing);

        //XOR bitwise operation; creates a mask with number 1 in bitPos
        //this causes the bit at bitPos to flip. the rest remains cause the mask as 0s and only a 1 in the bitPos
        uint256 mask = 1 << bitPos;
        self[wordPos] ^= mask;
    }

    /// @notice lte --> The flag that sets the direction. When true, we’re selling token X and searching for next initialized tick to the right
    /// of the current one. When false, it’s the other way around. lte equals to the swap direction: true when selling token x,
    /// false otherwise.
    function nextInitializedTickWithinOneWord(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing,
        bool lte
    ) internal view returns (int24 next, bool initialized) {
        int24 compressed = tick / tickSpacing;

        if (lte) {
            (int16 wordPos, uint8 bitPos) = position(compressed);
            //mask is all ones, its length = bitPos, so basically 1s right of bitPos(including itself) and 0s left
            uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
            uint256 masked = self[wordPos] & mask;
            //this way we can find inside a word if there is a bit == 1 if there is initialized = true otherwise false
            initialized = masked != 0;
            next = initialized
                ? (compressed -
                    int24(uint24(bitPos - BitMath.mostSignificantBit(masked))))
                : (compressed - int24(uint24(bitPos))) * tickSpacing;

            // this for the case we are selling y instead
        } else {
            (int16 wordPos, uint8 bitPos) = position(compressed + 1);
            uint256 mask = ~((1 << bitPos) - 1);
            uint256 masked = self[wordPos] & mask;

            initialized = masked != 0;

            next = initialized
                ? (compressed +
                    1 +
                    int24(
                        uint24(BitMath.leastSignificantBit(masked) - bitPos)
                    )) * tickSpacing
                : (compressed + 1 + int24(uint24((type(uint8).max - bitPos)))) *
                    tickSpacing;
        }
    }
}
