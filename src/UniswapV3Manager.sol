// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {UniswapV3Pool} from "src/UniswapV3Pool.sol";
import {IERC20} from "src/interfaces/IERC20.sol";

contract UniswapV3Manager {
    struct CallbackData {
        address token0;
        address token1;
        address payer;
    }

    function mint(
        address poolAddress_,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount,
        bytes calldata data
    ) public {
        UniswapV3Pool(poolAddress_).mint(
            msg.sender,
            lowerTick,
            upperTick,
            amount,
            data
        );
    }

    function swap(address poolAddress_, bytes calldata data) public {
        UniswapV3Pool(poolAddress_).swap(msg.sender, data);
    }

    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
        UniswapV3Pool.CallbackData memory extra = abi.decode(
            data,
            (UniswapV3Pool.CallbackData)
        );

        //approve was already set in the setupTest
        //in this case msg.sender is the pool contraxt through the callback, so the tokens are transfered from the user to the pool
        IERC20(extra.token0).transferFrom(
            extra.payer,
            msg.sender,
            uint256(amount0)
        );
        IERC20(extra.token1).transferFrom(
            extra.payer,
            msg.sender,
            uint256(amount1)
        );
    }

    function uniswapV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata data
    ) public {
        UniswapV3Pool.CallbackData memory extra = abi.decode(
            data,
            (UniswapV3Pool.CallbackData)
        );
        if (amount0 > 0) {
            IERC20(extra.token0).transferFrom(
                extra.payer,
                msg.sender,
                uint256(amount0)
            );
        }
        if (amount1 > 0) {
            IERC20(extra.token1).transferFrom(
                extra.payer,
                msg.sender,
                uint256(amount1)
            );
        }
    }
}
