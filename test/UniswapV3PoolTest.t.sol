// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "lib/forge-std/src/Test.sol";
import {ERC20Mintable} from "test/ERC20Mintable.t.sol";
import {UniswapV3Pool} from "src/UniswapV3Pool.sol";
import "lib/forge-std/src/console.sol";
import {IERC20} from "src/interfaces/IERC20.sol";


contract UniswapV3PoolTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniswapV3Pool pool;

    bool transferInMintCallback = true;
    bool transferInSwapCallback = true;


    struct TestCaseParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        int24 currentTick;
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
        uint160 currentSqrtP;
        bool transferInMintCallback;
        bool transferInSwapCallback;
        bool mintLiquidity;
    }

    function setUp() public {
        token0 = new ERC20Mintable("ETHER", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
    }

    //kind of a setUp() but only some test functions will use this extended logic (will be called internally
    // provides initial liquidity to the pool)
    function setupTestCase(TestCaseParams memory params) internal returns (uint256 poolBalance0, uint256 poolBalance1)
{
    token0.mint(address(this), params.wethBalance);
    token1.mint(address(this), params.usdcBalance);

    pool = new UniswapV3Pool(
        address(token0),
        address(token1),
        params.currentSqrtP,
        params.currentTick
    );

    if (params.mintLiquidity) {

        token0.approve(address(this), params.wethBalance);
        token1.approve((address(this)), params.usdcBalance);

        UniswapV3Pool.CallbackData memory extra = UniswapV3Pool.CallbackData({
            token0: address(token0),
            token1: address(token1),
            payer: address(this)})

        (poolBalance0, poolBalance1) = pool.mint(
            address(this),
            params.lowerTick,
            params.upperTick,
            params.liquidity,
            abi.encode(extra)
        );

        transferInMintCallback = params.transferInMintCallback;
        transferInSwapCallback = params.transferInSwapCallback;

    }

}
    // this function is called in the callback of the mint function of the uniswapV3pool contract
    //if removed the tokens won't be transfered to the pool. it has to have the exact same name as the callback function in contract
    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes calldata data) public {
        if (transferInMintCallback) {
            UniswapV3Pool.CallbackData memory extra = abi.decode(data, (UniswapV3Pool.CallbackData));
            IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
            IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
            

        }
        
    
    }

    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata data) public {
        if (transferInSwapCallback) {
            UniswapV3Pool.CallbackData memory extra = abi.decode(data, (UniswapV3Pool.CallBackData));
            if (amount0 > 0) {
                IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
            }
            if (amount1 > 0) {
                IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
            }
        }
    }

    //this function provides initial liquidity to the pool
    function testMintSuccess() public {
    TestCaseParams memory params = TestCaseParams({
        wethBalance: 1 ether,
        usdcBalance: 5000 ether,
        currentTick: 85176,
        lowerTick: 84222,
        upperTick: 86129,
        liquidity: 1517882343751509868544,
        currentSqrtP: 5602277097478614198912276234240,
        transferInMintCallback: true,
        transferInSwapCallback:true,
        mintLiquidity: true
    });
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        uint256 expectedAmount0 = 0.998976618347425280 ether;
        uint256 expectedAmount1 = 5000 ether;

        assertEq(expectedAmount0, poolBalance0, "Incorrect token0 deposited amount");
        assertEq(expectedAmount1, poolBalance1, "Incorrect token1 deposited amount");
        assertEq(expectedAmount0, token0.balanceOf(address(pool)));
        assertEq(expectedAmount1, token1.balanceOf(address(pool)));
        bytes32 positionKey = keccak256(abi.encodePacked(address(this), params.lowerTick, params.upperTick));
        uint128 posLiquidity = pool.positions(positionKey);
        //in the initial minting our liquidity position equals the whole liquidity of the pool
        assertEq(posLiquidity, params.liquidity);

        //check if lowerTick gets initialized and equals pool liquidity
        (bool lowerTickInitialized, uint128 lowerTickLiquidity) = pool.ticks(params.lowerTick);
        assertTrue(lowerTickInitialized);
        assertEq(lowerTickLiquidity, params.liquidity);
        //check if lowerTick gets initialized and equals pool liquidity
        (bool upperTickInitialized, uint128 upperTickLiquidity) = pool.ticks(params.upperTick);
        assertTrue(upperTickInitialized);
        assertEq(upperTickLiquidity, params.liquidity);

        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        assertEq(sqrtPriceX96, 5602277097478614198912276234240, "invalid sqrtPrice");
        assertEq(tick, 85176, "invalid tick");
        assertEq(pool.liquidity(), 1517882343751509868544, "invalid liquidity");
    }

    function testMintInvalidLowerTickRange() public {
        //random values used, we just want to test if (lowerTick >= upperTick || lowerTick < MIN_TICK || upperTick > MAX_TICK)
        pool = new UniswapV3Pool(
        address(token0),
        address(token1),
        0, 
        0);

        vm.expectRevert(abi.encodeWithSelector(UniswapV3Pool.InvalidTickRange.selector));
        pool.mint(address(this), -887273, 0, 0);
    }

    function testMintInvalidLowerUpperRange() public {
        pool = new UniswapV3Pool(
        address(token0),
        address(token1),
        1,
        0);

        vm.expectRevert(abi.encodeWithSelector(UniswapV3Pool.InvalidTickRange.selector));
        pool.mint(address(this), 887273, 0, 0);
    }

    function testMintZeroAmount() public {
        pool = new UniswapV3Pool(
        address(token0),
        address(token1),
        0,
        0);

        vm.expectRevert(abi.encodeWithSelector(UniswapV3Pool.ZeroLiquidity.selector));
        pool.mint(address(this), -1, 1, 0);
    }
    
    //not working correctly , something throwing arithmetic over/underflow in the ERC20Mintable transfer function
    function testRevertsNotEnoughTokens() public {
    TestCaseParams memory params = TestCaseParams({
        wethBalance: 0 ether,
        usdcBalance: 0 ether,
        currentTick: 85176,
        lowerTick: 84222,
        upperTick: 86129,
        liquidity: 517882343751509868544,
        currentSqrtP: 5602277097478614198912276234240,
        transferInMintCallback: true,
        transferInSwapCallback:true,
        mintLiquidity: true
        });

                
        
        //its not revertting with the expected revert because something of the logic is off, maybe the hardcoded values in the contract
        // because then it conflits with how much is minted in ERC20mintable, interfering with transfer, have to draw a diagram to see
        //maybe the callbacl function... (check the extra calldata in the github of the project!!)
        setupTestCase(params);
        
    }

    function testSwapBuyEth() public {
    TestCaseParams memory params = TestCaseParams({
        wethBalance: 1 ether,
        usdcBalance: 5000 ether,
        currentTick: 85176,
        lowerTick: 84222,
        upperTick: 86129,
        liquidity: 1517882343751509868544,
        currentSqrtP: 5602277097478614198912276234240,
        transferInMintCallback: true,
        transferInSwapCallback: true,
        mintLiquidity: true
    });

    (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

    uint256 swapAmount = 42 ether;

    token1.mint(address(this), swapAmount);

    (int256 amount0Delta, int256 amount1Delta) = pool.swap(address(this));
    assertEq(amount0Delta, -0.008396714242162444 ether, "invalid ETH out");
    assertEq(amount1Delta, 42 ether, "invalid USDC in");

    int256 userBalance0Before = int256(token0.balanceOf(address(this)));
    int256 userBalance1Before = int256(token1.balanceOf(address(this)));


    // check user balance after transfer
    assertEq(token0.balanceOf(address(this)), uint256(userBalance0Before - amount0Delta), "invalid ETH balance");
    assertEq(token1.balanceOf(address(this)), 0, "invalid USDC balance"); // we only minted 42 so it should be 0 after transfer of 42;

    //check pool balance after transfer
    assertEq(token0.balanceOf(address(pool)), uint256(int256(poolBalance0) + amount0Delta), "invalid ETH balance in pool");
    assertEq(token1.balanceOf(address(pool)), uint256(int256(poolBalance1) + amount1Delta), "invalid USDC balance in pool");

    (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
    assertEq(sqrtPriceX96, 5604469350942327889444743441197, "invalid price");
    assertEq(tick, 85184, "invalid tick");
    assertEq(pool.liquidity(), 1517882343751509868544, "invalid liquidity");
    }

}