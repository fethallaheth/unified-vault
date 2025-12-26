// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";
import {IAavePool} from "../interfaces/IAavePool.sol";
import {IAaveAddressesProvider} from "../interfaces/IAaveAddressesProvider.sol";

/**
 * @title AaveStrategyV3
 * @notice Simple Aave V3 Strategy without external dependencies.
 */
contract AaveStrategyV3 is IStrategy {
    using SafeERC20 for IERC20;

    // --- State Variables ---

    IERC20 public immutable asset;
    IAavePool public immutable aavePool;
    IERC20 public immutable aToken;

    uint16 private constant REFERRAL_CODE = 0;

    // --- Constructor ---

    /**
     * @param _asset The underlying asset address (e.g., USDC).
     * @param _poolProvider The Aave PoolAddressesProvider address for your chain.
     */
    constructor(address _asset, address _poolProvider) {
        asset = IERC20(_asset);
        
        // 1. Get the Pool contract from the Provider
        IAaveAddressesProvider provider = IAaveAddressesProvider(_poolProvider);
        aavePool = IAavePool(provider.getPool());

        // 2. Get the aToken address from the Reserve Data
        IAavePool.ReserveData memory reserveData = aavePool.getReserveData(_asset);
        aToken = IERC20(reserveData.aTokenAddress);

        // 3. Give Aave Max Approval
        asset.forceApprove(address(aavePool), type(uint256).max);
    }

    // --- Core Strategy Functions ---

    // NOTE ADD ONLYVAULT 
    function deposit(uint256 amount) external override {
        require(amount > 0, "Amount must be > 0");
        aavePool.supply(address(asset), amount, address(this), REFERRAL_CODE);
    }

    function withdraw(uint256 amount) external override returns (uint256) {
        uint256 balanceBefore = asset.balanceOf(address(this));
        aavePool.withdraw(address(asset), amount, address(this));
        uint256 balanceAfter = asset.balanceOf(address(this));

        uint256 amountWithdrawn = balanceAfter - balanceBefore;
        
        asset.safeTransfer(msg.sender, amountWithdrawn);
        return amountWithdrawn;
    }

    function totalAssets() external view override returns (uint256) {
        return aToken.balanceOf(address(this));
    }
}