// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/*
  Generic base for all strategies.
  - Minimal, strategy-agnostic interface and helpers
  - Concrete strategies (liquidity, staking, lending) should inherit and implement
  - Vault is owner of accounting and orchestrates deposits/withdrawals
*/
abstract contract BaseStrategy {
    using SafeERC20 for IERC20;

    address public immutable vault;

    modifier onlyVault() {
        require(msg.sender == vault, "NOT_VAULT");
        _;
    }

    constructor(address _vault) {
        require(_vault != address(0), "ZERO_VAULT");
        vault = _vault;
    }

    // Strategy should implement how it accepts deposits. `params` is strategy-specific ABI.
    function deposit(bytes calldata params) external virtual;

    // Withdraw assets back to the vault. `params` is strategy-specific ABI.
    function withdraw(bytes calldata params) external virtual;

    // Report total managed assets in an asset-agnostic unit (uint256). Vault uses this for share math.
    function totalAssets() external view virtual returns (uint256);

    // Return the list of ERC20 tokens the strategy may send to the vault on withdraw.
    // This lets the vault forward tokens to users after a withdraw call.
    function tokens() external view virtual returns (address[] memory);

    // Helpers
    function _forwardToken(address token, address to, uint256 amount) internal {
        if (amount > 0) IERC20(token).safeTransfer(to, amount);
    }
}
