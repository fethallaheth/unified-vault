// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStrategy {
    // Deposit into the strategy. `params` is strategy-specific ABI encoded data.
    function deposit(bytes calldata params) external;

    // Withdraw from the strategy. `params` is strategy-specific ABI encoded data.
    function withdraw(bytes calldata params) external;

    // Report total managed assets in a uint256 unit (vault uses this for share math).
    function totalAssets() external view returns (uint256);

    // Return tokens the strategy may send to the vault on withdraw.
    function tokens() external view returns (address[] memory);
}
