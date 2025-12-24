// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IPoolManager } from "v4-core/src/interfaces/IPoolManager.sol";
import { PoolKey } from "v4-core/src/types/PoolKey.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract SimpleUniV4Strategy {
    address public immutable vault;
    IPoolManager public immutable poolManager;
    PoolKey public poolKey;

    IERC20 public immutable token0;
    IERC20 public immutable token1;

    int24 public immutable tickLower;
    int24 public immutable tickUpper;

    uint128 public liquidity;

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

        token0 = IERC20(_poolKey.currency0.unwrap());
        token1 = IERC20(_poolKey.currency1.unwrap());

        tickLower = _tickLower;
        tickUpper = _tickUpper;
    }

    /* ---------------- DEPOSIT ---------------- */

    function deposit(uint256 amount0, uint256 amount1) external onlyVault {
        token0.approve(address(poolManager), amount0);
        token1.approve(address(poolManager), amount1);

        uint128 liq = uint128(
            poolManager.modifyLiquidity(
                poolKey,
                IPoolManager.ModifyLiquidityParams({
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: int128(uint128(amount0 + amount1)) // simplified
                }),
                abi.encode(address(this))
            )
        );

        liquidity += liq;
    }

    /* ---------------- WITHDRAW ---------------- */

    function withdraw(uint128 liq) external onlyVault {
        poolManager.modifyLiquidity(
            poolKey,
            IPoolManager.ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: -int128(liq)
            }),
            abi.encode(address(this))
        );

        liquidity -= liq;

        token0.transfer(vault, token0.balanceOf(address(this)));
        token1.transfer(vault, token1.balanceOf(address(this)));
    }

    /* ---------------- VIEW ---------------- */

    function totalLiquidity() external view returns (uint128) {
        return liquidity;
    }
}
