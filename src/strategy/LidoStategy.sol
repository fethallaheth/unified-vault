
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ILido } from "../interfaces/ILido.sol";

contract LidoStakingStrategy {
    address public immutable vault;
    ILido public immutable lido;
    IERC20 public immutable stETH;

    uint256 public totalStaked;

    modifier onlyVault() {
        require(msg.sender == vault, "NOT_VAULT");
        _;
    }

    constructor(address _vault, address _lido, address _stETH) {
        vault = _vault;
        lido = ILido(_lido);
        stETH = IERC20(_stETH);
    }

    /* ---------------- DEPOSIT ---------------- */
    function deposit() external payable onlyVault {
        require(msg.value > 0, "NO_ETH_SENT");

        // Stake ETH in Lido
        lido.submit{value: msg.value}(address(0));

        // Update accounting
        totalStaked += msg.value;
    }

    /* ---------------- WITHDRAW ---------------- */
    function withdraw(uint256 stETHAmount) external onlyVault {
        // In Lido, stETH cannot be unwrapped instantly (Ethereum lockup)
        // For simplicity, we just transfer stETH to vault
        require(stETH.balanceOf(address(this)) >= stETHAmount, "INSUFFICIENT_BALANCE");
        stETH.transfer(vault, stETHAmount);

        // Update accounting
        totalStaked -= stETHAmount;
    }

    /* ---------------- VIEW ---------------- */
    function totalAssets() external view returns (uint256) {
        // total stETH held by the strategy (already includes accrued yield)
        return stETH.balanceOf(address(this));
    }
}
