// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";
import {IAavePool} from "../interfaces/IAavePool.sol";
import {IPoolAddressesProvider} from "../interfaces/IPoolAddressesProvider.sol";
import {BaseStrategy} from "./Base/BaseStrategy.sol";

/// @title AaveStrategyV3 Contract
/// @author fethallahEth
/// @notice Strategy for interacting with Aave V3 protocol.
/// @dev This contract inherits from BaseStrategy and implements deposit, withdraw, and totalAssets functions for Aave V3.
contract AaveStrategyV3 is BaseStrategy {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    IAavePool public immutable aavePool;
    IERC20 public immutable aToken;

    uint16 private constant REFERRAL_CODE = 0;

    constructor(address _vault, address _asset, address _poolProvider) BaseStrategy(_vault) {
        asset = IERC20(_asset);

        IPoolAddressesProvider  provider = IPoolAddressesProvider(_poolProvider);
        aavePool = IAavePool(provider.getPool());

        IAavePool.ReserveData memory reserveData = aavePool.getReserveData(_asset);
        aToken = IERC20(reserveData.aTokenAddress);

        SafeERC20.forceApprove(asset, address(aavePool), type(uint256).max);
    }

    function deposit(uint256 amount) external override onlyVault {
        require(amount > 0, "Amount must be > 0");
        aavePool.supply(address(asset), amount, address(this), REFERRAL_CODE);
    }

    // this is not work with wierd tokens
    function withdraw(uint256 amount) external override onlyVault returns (uint256) {
        uint256 amountWithdrawn = aavePool.withdraw(address(asset), amount, address(this));
        // @note it should to transfer it to the user who call the withdraw on the vault 
        asset.safeTransfer(msg.sender, amountWithdrawn);
        return amountWithdrawn;
    }

    function totalAssets() external view override returns (uint256) {
        return aToken.balanceOf(address(this));
    }


}
