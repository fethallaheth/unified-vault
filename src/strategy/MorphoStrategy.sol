// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";
import {IMorpho} from "../interfaces/IMorpho.sol";
// Import BaseStrategy
import {BaseStrategy} from "./Base/BaseStrategy.sol";

contract MorphoStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    IMorpho public immutable morpho;
    IMorpho.MarketParams public marketParams;


    constructor(
        address _vault,
        address _asset,
        address _morpho,
        address _loanToken,
        address _collateralToken,
        address _oracle,
        address _irm,
        address _lltv
    ) BaseStrategy(_vault) {
        asset = IERC20(_asset);
        morpho = IMorpho(_morpho);

        marketParams = IMorpho.MarketParams({
            loanToken: _loanToken,
            collateralToken: _collateralToken,
            oracle: _oracle,
            irm: _irm,
            lltv: _lltv
        });

        SafeERC20.forceApprove(asset, _morpho, type(uint256).max);
    }


    function deposit(uint256 amount) external override onlyVault {
        require(amount > 0, "Amount must be > 0");
        morpho.supply(marketParams, amount, address(this), "");
    }

    function withdraw(uint256 amount) external override onlyVault returns (uint256) {
        uint256 amountWithdrawn = morpho.withdraw(marketParams, amount, msg.sender, address(this));
        return amountWithdrawn;
    }

    function totalAssets() external view override returns (uint256) {
        uint256 shares = morpho.balanceOf(marketParams, address(this));
        return morpho.convertToAssets(marketParams, shares);
    }

}
