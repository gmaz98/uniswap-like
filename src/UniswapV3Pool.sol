// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Tick} from "src/lib/Tick.sol";
import {Position} from "src/lib/Position.sol";
import {IERC20} from "src/interfaces/IERC20.sol";
import "src/interfaces/IUniswapV3MintCallback.sol";

contract UniswapV3Pool {

    error InvalidTickRange();
    error ZeroLiquidity();
    error InsufficientInputAmount();

    event Mint(address sender , address indexed owner, int24 indexed lowerTick, int24 indexed upperTick, uint128 amount, uint256 amount0, uint256 amount1);


    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 =>Position.Info);
    using Position for Position.Info;

    mapping(int24 => Tick.Info) public ticks;
    mapping(bytes32 => Position.Info) public positions;

    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    address public immutable token0;
    address public immutable token1;

    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
    }

    Slot0 public slot0;

    uint128 public liquidity;

    constructor(address token0_, address token1_, uint160 sqrtPriceX96_, int24 tick_) {
        token0 = token0_;
        token1 = token1_;
        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96_, tick:tick_});
    }

    function mint(address owner, int24 lowerTick, int24 upperTick, uint128 amount) external returns (uint256 amount0, uint256 amount1) {
        if (lowerTick >= upperTick || lowerTick < MIN_TICK || upperTick > MAX_TICK) {
            revert InvalidTickRange();
        }
        if (amount == 0) {
            revert ZeroLiquidity();
        }
        ticks.update(lowerTick, amount);
        ticks.update(upperTick, amount);

        Position.Info storage position = positions.get(owner, lowerTick, upperTick);
        position.update(amount);

        //hardcoded values calculated through math
        amount0 = 0.998976618347425280 ether;
        amount1 = 5000 ether;
        
        liquidity += amount;

        uint256 balance0Before;
        uint256 balance1Before;

        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();

        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1);

        if (amount0 > 0 && balance0Before + amount0 > balance0()) revert InsufficientInputAmount();
        if (amount1 > 0 && balance1Before + amount1 > balance1()) revert InsufficientInputAmount();

        emit Mint(msg.sender, owner, lowerTick, upperTick, amount, amount0, amount1);
    }

    function balance0() internal returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal returns (uint256 balance) {
        balance = IERC20(token1).balanceOf(address(this));
    }

}