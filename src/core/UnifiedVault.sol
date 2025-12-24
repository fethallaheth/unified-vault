// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC6909} from "@openzeppelin/contracts/token/ERC6909/ERC6909.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract UnifiedVault is ERC6909, Ownable {
    using SafeERC20 for IERC20;

    uint256[] public Ids;
    mapping(uint256 => uint256) public totalAssets;
    mapping(uint256 => uint256) public totalShares;
    mapping(uint256 => address) public assetToken;

    constructor() Ownable(msg.sender) {}

    function previewDeposit(uint256 id, uint256 assets) public view returns (uint256) {
        return convertToShares(id, assets);
    }

    function previewWithdraw(uint256 id, uint256 shares) public view returns (uint256) {
        return convertToAssets(id, shares);
    }

    function deposit(uint256 id, uint256 assets) external {
        address asset = assetToken[id];
        require(asset != address(0), "Asset not registered");
        require(assets > 0, "Amount must be > 0");

        uint256 shares = _convertToShares(id, assets);
        require(shares > 0, "Zero shares");

        totalAssets[id] += assets;
        totalShares[id] += shares;
        _mint(msg.sender, id, shares);

        IERC20(asset).safeTransferFrom(msg.sender, address(this), assets);
    }

    function withdraw(uint256 id, uint256 shares) external {
        address asset = assetToken[id];
        require(asset != address(0), "Asset not registered");
        require(balanceOf(msg.sender, id) >= shares, "Not enough shares");

        uint256 assets = _convertToAssets(id, shares);

        _burn(msg.sender, id, shares);
        totalShares[id] -= shares;
        totalAssets[id] -= (shares * totalAssets[id]) / totalShares[id]; // only principal

        IERC20(asset).safeTransfer(msg.sender, assets);
    }

    function harvest(uint256 id) external onlyOwner {
        // TODO
    }

    ///////////////////////////////// ASSET MANAGEMENT /////////////////////////////////

    function registerAsset(address asset) external onlyOwner {
        uint256 id = Ids.length;
        require(assetToken[id] == address(0), "Asset already registered");
        assetToken[id] = asset;
        Ids.push(id);
    }

    function removeAsset(uint256 id) external onlyOwner {
        require(assetToken[id] != address(0), "Asset not registered");
        require(totalShares[id] == 0, "Pool not empty");
        assetToken[id] = address(0);
        for (uint256 i = 0; i < Ids.length; i++) {
            if (Ids[i] == id) {
                Ids[i] = Ids[Ids.length - 1];
                Ids.pop();
                break;
            }
        }
    }

    ///////////////////////////////// INTERNAL LOGIC /////////////////////////////////

    function _currentTotalAssets(uint256 id) internal view returns (uint256) {
        // Always use actual contract balance for yield-aware math
        address asset = assetToken[id];
        // @note not supporting native ETH for now
        if (asset == address(0)) return 0;
        return IERC20(asset).balanceOf(address(this));
    }

    // @note inflation attack
    function convertToShares(uint256 id, uint256 assets) public view returns (uint256) {
        uint256 shares = _convertToShares(id, assets);
        return shares;
    }

    function convertToAssets(uint256 id, uint256 shares) public view returns (uint256) {
        uint256 assets = _convertToAssets(id, shares);
        return assets;
    }

    function _convertToShares(uint256 id, uint256 assets) internal view returns (uint256) {
        uint256 _totalShares = totalShares[id];
        uint256 _totalAssets = _currentTotalAssets(id);
        if (_totalShares == 0 || _totalAssets == 0) {
            return assets;
        }
        return Math.mulDiv(assets, _totalShares, _totalAssets, Math.Rounding.Floor);
    }

    function _convertToAssets(uint256 id, uint256 shares) internal view returns (uint256) {
        uint256 _totalShares = totalShares[id];
        uint256 _totalAssets = _currentTotalAssets(id);
        require(_totalShares > 0, "No shares exist");
        return Math.mulDiv(shares, _totalAssets, _totalShares, Math.Rounding.Ceil);
    }
}
