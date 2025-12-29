// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title BaseStrategy Abstract Contract
/// @author fethallahEth
/// @notice Abstract contract that defines the basic structure and functionality for a strategy.
/// @dev This contract should be inherited by specific strategy implementations.
abstract contract BaseStrategy {
    using SafeERC20 for IERC20;
    
    address public immutable vault;
    
    /// @notice Modifier to restrict function access to the vault only.
    /// @dev This modifier checks if the caller is the vault address, as some functions should only be callable by the vault.
    modifier onlyVault() {
        require(msg.sender == vault, "NOT_VAULT");
        _;
    }

    constructor(address _vault) {
        require(_vault != address(0), "ZERO_VAULT");
        vault = _vault;
    }

    // Strategy should implement how it accepts deposits.
    function deposit(uint256 amount) external virtual;

    // Withdraw assets back to the vault. 
    function withdraw(uint256 amount) external virtual returns (uint256);

    // Report total managed assets in an asset-agnostic unit (uint256). Vault uses this for share math.
    function totalAssets() external view virtual returns (uint256);


}
