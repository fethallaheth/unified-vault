// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IStrategy {
    /**
     * @notice Deposit assets into the protocol.
     * @param amount The amount of assets to deposit.
     */
    function deposit(uint256 amount) external;

    /**
     * @notice Withdraw assets from the protocol.
     * @param amount The amount of assets to withdraw.
     * @return The actual amount of assets withdrawn (may differ if slippage/loss).
     */
    function withdraw(uint256 amount) external returns (uint256);

    /**
     * @notice View the total assets currently managed by this strategy.
     * @return The total balance of assets in the protocol.
     */
    function totalAssets() external view returns (uint256);
}