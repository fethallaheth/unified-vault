// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IMorpho {
    /**
     * @notice Struct identifying a Morpho market
     * @dev You must provide these specific addresses for the market you want to target
     */
    struct MarketParams {
        address loanToken;       // The underlying borrowed asset (e.g., WBTC)
        address collateralToken;  // The asset you are supplying (e.g., USDC)
        address oracle;           // The price oracle contract for this pair
        address irm;              // The interest rate model contract
        address lltv;             // The loan-to-value curve contract
    }

    /**
     * @notice Supplies assets to the protocol
     * @param marketParams The market configuration
     * @param assets The amount of assets to supply
     * @param onBehalfOf The address that will own the position
     * @param referralCode The referral code (0 if none)
     */
    function supply(
        MarketParams calldata marketParams,
        uint256 assets,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    /**
     * @notice Withdraws assets from the protocol
     * @param marketParams The market configuration
     * @param assets The amount of assets to withdraw
     * @param receiver The address that receives the assets
     * @param owner The address that owns the position
     * @return The amount of assets withdrawn
     */
    function withdraw(
        MarketParams calldata marketParams,
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256);

    /**
     * @notice Returns the number of shares owned by an account in a market
     * @param marketParams The market configuration
     * @param account The address to check
     */
    function balanceOf(
        MarketParams calldata marketParams,
        address account
    ) external view returns (uint256);

    /**
     * @notice Converts a number of shares to underlying assets
     * @param marketParams The market configuration
     * @param shares The amount of shares
     */
    function convertToAssets(
        MarketParams calldata marketParams,
        uint256 shares
    ) external view returns (uint256);
}