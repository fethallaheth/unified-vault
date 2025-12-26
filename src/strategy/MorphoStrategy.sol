// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";
import {IMorpho} from "../interfaces/IMorpho.sol";

/**
 * @title MorphoStrategy
 * @notice Simple Morpho Blue Supply-Only Strategy
 * @dev This strategy supplies an asset (Collateral) into a specific Morpho market.
 *      It does NOT borrow.
 */
contract MorphoStrategy is IStrategy {
    using SafeERC20 for IERC20;

    // --- State Variables ---

    IERC20 public immutable asset;
    IMorpho public immutable morpho;
    
    /// @notice The specific Morpho market parameters (Target Market)
    IMorpho.MarketParams public marketParams;

    uint16 private constant REFERRAL_CODE = 0;

    // --- Constructor ---

    /**
     * @param _asset The asset you are supplying (e.g., USDC).
     * @param _morpho The Morpho Blue Main contract address.
     * @param _loanToken The asset being borrowed in this market (e.g., WBTC).
     * @param _collateralToken The asset you are supplying (usually same as _asset).
     * @param _oracle The oracle address for this market.
     * @param _irm The interest rate model address for this market.
     * @param _lltv The loan to value curve address for this market.
     */
    constructor(
        address _asset,
        address _morpho,
        address _loanToken,
        address _collateralToken,
        address _oracle,
        address _irm,
        address _lltv
    ) {
        asset = IERC20(_asset);
        morpho = IMorpho(_morpho);

        // Set up the market parameters
        marketParams = IMorpho.MarketParams({
            loanToken: _loanToken,
            collateralToken: _collateralToken,
            oracle: _oracle,
            irm: _irm,
            lltv: _lltv
        });

        // Give Morpho Max Approval
        asset.forceApprove(_morpho, type(uint256).max);
    }

    // --- Core Strategy Functions ---

    /**
     * @notice Supply assets to Morpho
     */
    function deposit(uint256 amount) external override {
        require(amount > 0, "Amount must be > 0");
        morpho.supply(marketParams, amount, address(this), REFERRAL_CODE);
    }

    /**
     * @notice Withdraw assets from Morpho
     */
    function withdraw(uint256 amount) external override returns (uint256) {
        // Morpho returns the actual amount withdrawn (shares -> assets)
        uint256 amountWithdrawn = morpho.withdraw(
            marketParams, 
            amount, 
            msg.sender,  // Send assets directly to the Vault
            address(this) // Owner is this contract
        );
        return amountWithdrawn;
    }

    /**
     * @notice Get total assets held in Morpho
     * @dev We must query shares, then convert to assets
     */
    function totalAssets() external view override returns (uint256) {
        // 1. Get our shares in this market
        uint256 shares = morpho.balanceOf(marketParams, address(this));
        
        // 2. Convert shares to underlying asset amount
        return morpho.convertToAssets(marketParams, shares);
    }
}