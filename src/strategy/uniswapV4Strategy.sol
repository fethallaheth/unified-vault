// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPoolManager, PoolKey, ModifyLiquidityParams} from "../interfaces/IPoolManager.sol";

/**
 * Minimal, self-contained base strategy for Uniswap v4-style pool managers.
 *
 * NOTE: This file declares very small local types for `IPoolManager` and
 * `PoolKey` to avoid hard dependency on external v4-core types in this
 * example. In production you should import the canonical v4-core types.
 */
contract SimpleUniV4Strategy {
    using SafeERC20 for IERC20;

    // PoolKey and ModifyLiquidityParams imported from interfaces/IPoolManager.sol

    address public immutable vault;
    IPoolManager public immutable poolManager;
    PoolKey public poolKey;

    IERC20 public immutable token0;
    IERC20 public immutable token1;

    int24 public immutable tickLower;
    int24 public immutable tickUpper;

    uint128 public liquidity; // tracked liquidity units

    event Deposited(uint128 liquidityDelta, uint256 amount0, uint256 amount1);
    event Withdrawn(uint128 liquidityDelta, uint256 out0, uint256 out1);

    modifier onlyVault() {
        require(msg.sender == vault, "NOT_VAULT");
        _;
    }

    constructor(
        address _vault,
        IPoolManager _poolManager,
        PoolKey memory _poolKey,
        int24 _tickLower,
        int24 _tickUpper
    ) {
        vault = _vault;
        poolManager = _poolManager;
        poolKey = _poolKey;

        token0 = IERC20(_poolKey.currency0);
        token1 = IERC20(_poolKey.currency1);

        tickLower = _tickLower;
        tickUpper = _tickUpper;
    }

    /**
     * Deposit liquidity into the pool.
     * Caller (vault) must pre-transfer `amount0` and `amount1` into this strategy
     * or to the pool as required by the real pool manager implementation.
     */
    function deposit(
        uint128 liquidityDelta,
        uint256 amount0,
        uint256 amount1
    ) external onlyVault {
        require(liquidityDelta > 0, "ZERO_LIQ");

        // Approve exact amounts to poolManager
        token0.forceApprove(address(poolManager), 0);
        token0.forceApprove(address(poolManager), amount0);
        token1.forceApprove(address(poolManager), 0);
        token1.forceApprove(address(poolManager), amount1);

        uint128 liqReturned = poolManager.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int128(liquidityDelta)
            }),
            abi.encode(address(this))
        );

        liquidity += liqReturned;

        // reset approvals
        token0.forceApprove(address(poolManager), 0);
        token1.forceApprove(address(poolManager), 0);

        emit Deposited(liqReturned, amount0, amount1);
    }

    /**
     * Withdraw liquidity by liquidityDelta. Tokens received are expected to be
     * forwarded to this contract by the pool manager; the strategy then sends
     * them back to the vault.
     */
    function withdraw(uint128 liquidityDelta) external onlyVault {
        require(liquidityDelta > 0 && liquidityDelta <= liquidity, "BAD_LIQ");

        uint128 liqReturned = poolManager.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: -int128(liquidityDelta)
            }),
            abi.encode(address(this))
        );

        liquidity -= liqReturned;

        // transfer all token balances back to vault
        uint256 out0 = token0.balanceOf(address(this));
        uint256 out1 = token1.balanceOf(address(this));

        if (out0 > 0) token0.safeTransfer(vault, out0);
        if (out1 > 0) token1.safeTransfer(vault, out1);

        emit Withdrawn(liqReturned, out0, out1);
    }

    function totalLiquidity() external view returns (uint128) {
        return liquidity;
    }
}
