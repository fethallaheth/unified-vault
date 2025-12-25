// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Simplified local PoolKey and ModifyLiquidityParams used by strategies in this repo.
struct PoolKey {
    address pool; // placeholder for actual pool identifier
    address currency0;
    address currency1;
}

struct ModifyLiquidityParams {
    int24 tickLower;
    int24 tickUpper;
    int128 liquidityDelta;
}

interface IPoolManager {
    function modifyLiquidity(
        PoolKey calldata poolKey,
        ModifyLiquidityParams calldata params,
        bytes calldata data
    ) external returns (uint128);
}
