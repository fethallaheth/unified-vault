// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC6909} from "@openzeppelin/contracts/token/ERC6909/ERC6909.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";

contract UnifiedVault is ERC6909, Ownable {
    using SafeERC20 for IERC20;

    uint256[] public Ids;
    mapping(uint256 => uint256) public totalAssets;
    mapping(uint256 => uint256) public totalShares;
    mapping(uint256 => address) public assetToken;

    // Strategy infra (multi-strategy per assetId)
    mapping(uint256 => address[]) public strategies; // assetId => strategy addresses
    mapping(uint256 => uint256) public activeStrategy; // assetId => active strategy index

    // Virtual values to mitigate donation/inflation attacks (ERC-4626 style)
    uint256 internal constant VIRTUAL_SHARES = 10 ** 18;
    uint256 internal constant VIRTUAL_ASSETS = 1;

    // Use external `IStrategy` interface from src/interfaces/IStrategy.sol

    event StrategyAdded(uint256 indexed id, address strategy);
    event StrategyRemoved(uint256 indexed id, address strategy);
    event ActiveStrategySet(uint256 indexed id, uint256 index);
    event DepositToStrategy(uint256 indexed id, address indexed strategy, uint256 sharesMinted, uint256 assetsAdded);
    event WithdrawFromStrategy(uint256 indexed id, address indexed strategy, uint256 sharesBurned, uint256 out0, uint256 out1);

    constructor() Ownable(msg.sender) {}

    function previewDeposit(uint256 id, uint256 assets) public view returns (uint256) {
        return _convertToShares(id, assets, Math.Rounding.Floor);
    }

    function previewWithdraw(uint256 id, uint256 shares) public view returns (uint256) {
        return _convertToAssets(id, shares, Math.Rounding.Ceil);
    }

    function deposit(uint256 id, uint256 assets) external {
        address asset = assetToken[id];
        require(asset != address(0), "Asset not registered");
        require(assets > 0, "Amount must be > 0");

        uint256 shares = _convertToShares(id, assets, Math.Rounding.Floor);
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

        uint256 prevTotalShares = totalShares[id];
        require(prevTotalShares > 0, "No shares exist");
        uint256 prevTotalAssets = totalAssets[id];

        // assets to send = shares * contractBalance / prevTotalShares  (includes yield)
        uint256 contractBalance = _currentTotalAssets(id);
        uint256 assetsToSend = _mulDiv(shares, contractBalance, prevTotalShares, Math.Rounding.Ceil);

        // principal portion to remove from totalAssets
        uint256 principalRemoved;
        if (shares == prevTotalShares) {
            principalRemoved = prevTotalAssets;
            totalAssets[id] = 0;
            totalShares[id] = 0;
        } else {
            principalRemoved = _mulDiv(shares, prevTotalAssets, prevTotalShares, Math.Rounding.Floor);
            totalAssets[id] = prevTotalAssets - principalRemoved;
            totalShares[id] = prevTotalShares - shares;
        }

        _burn(msg.sender, id, shares);

        IERC20(asset).safeTransfer(msg.sender, assetsToSend);
    }

    function harvest(uint256 id) external onlyOwner {
        // absorb yield: set principal to actual balance
        uint256 bal = _currentTotalAssets(id);
        require(bal >= totalAssets[id], "Invariant violated");
        totalAssets[id] = bal;
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

    // Strategy management
    function addStrategy(uint256 id, address strategy) external onlyOwner {
        require(assetToken[id] != address(0), "Asset not registered");
        require(strategy != address(0), "ZERO_STRAT");
        strategies[id].push(strategy);
        emit StrategyAdded(id, strategy);
    }

    function removeStrategy(uint256 id, uint256 index) external onlyOwner {
        require(index < strategies[id].length, "INDEX_OOB");
        address strat = strategies[id][index];
        uint256 last = strategies[id].length - 1;
        if (index != last) strategies[id][index] = strategies[id][last];
        strategies[id].pop();
        emit StrategyRemoved(id, strat);
        if (activeStrategy[id] > last - 1) activeStrategy[id] = 0;
    }

    function setActiveStrategy(uint256 id, uint256 index) external onlyOwner {
        require(index < strategies[id].length, "INDEX_OOB");
        activeStrategy[id] = index;
        emit ActiveStrategySet(id, index);
    }

    function getStrategies(uint256 id) external view returns (address[] memory) {
        return strategies[id];
    }

    function _strategyFor(uint256 id, uint256 index) internal view returns (address) {
        if (strategies[id].length == 0) return address(0);
        if (index >= strategies[id].length) index = activeStrategy[id];
        return strategies[id][index];
    }

    // Deposit into a strategy-backed pool. Caller supplies tokens and precomputed liquidityDelta.
    // Caller must ensure necessary tokens are transferred to the strategy OR strategy can pull them.
    // `params` is strategy-specific ABI and allows flexibility for liquidity, staking, loans, etc.
    // NOTE
    // add a logic rebalancing the used vault and add a prefered vault so that depositToStrategy uses the prefered vault 
    // ill remove this shit later (depositTostrategy)






    // --- 


    function depositToStrategy(uint256 id, bytes calldata params) external {
        address strat = _strategyFor(id, activeStrategy[id]);
        require(strat != address(0), "NO_STRAT");

        IStrategy s = IStrategy(strat);

        uint256 prevTotalAssets = _currentTotalAssets(id);
        uint256 prevTotalShares = totalShares[id];

        // call strategy to deposit (strategy is responsible for pulling tokens or using pre-transferred funds)
        s.deposit(params);

        uint256 newTotalAssets = _currentTotalAssets(id);
        require(newTotalAssets >= prevTotalAssets, "STRAT_INV");
        uint256 addedAssets = newTotalAssets - prevTotalAssets;

        uint256 shares;
        if (prevTotalShares == 0 || prevTotalAssets == 0) {
            shares = addedAssets;
        } else {
            shares = _mulDiv(addedAssets, prevTotalShares, prevTotalAssets, Math.Rounding.Floor);
        }
        require(shares > 0, "ZERO_SHARES");

        totalAssets[id] = newTotalAssets;
        totalShares[id] = prevTotalShares + shares;
        _mint(msg.sender, id, shares);

        emit DepositToStrategy(id, strat, shares, addedAssets);
    }

    // Withdraw from strategy by burning shares. Vault computes liquidity to remove.
    // Withdraw from strategy by burning shares. `params` is strategy-specific ABI.
    function withdrawFromStrategy(uint256 id, uint256 shares, bytes calldata params) external {
        address strat = _strategyFor(id, activeStrategy[id]);
        require(strat != address(0), "NO_STRAT");
        require(balanceOf(msg.sender, id) >= shares, "NOT_ENOUGH_SHARES");

        IStrategy s = IStrategy(strat);
        address[] memory toks = s.tokens();

        uint256 prevTotalAssets = _currentTotalAssets(id);
        uint256 prevTotalShares = totalShares[id];
        require(prevTotalShares > 0, "NO_SHARES");

        // snapshot token balances to measure received amounts
        uint256[] memory beforeBalances = new uint256[](toks.length);
        for (uint256 i = 0; i < toks.length; i++) beforeBalances[i] = IERC20(toks[i]).balanceOf(address(this));

        // call strategy to withdraw -> strategy should transfer tokens to this vault
        s.withdraw(params);

        // compute out amounts and forward to user after accounting
        // We avoid storing `after` and `out` arrays to reduce stack/memory usage.

        // burn shares and update accounting (remove principal portion)
        uint256 principalRemoved;
        if (shares == prevTotalShares) {
            principalRemoved = totalAssets[id];
            totalAssets[id] = 0;
            totalShares[id] = 0;
        } else {
            principalRemoved = _mulDiv(shares, totalAssets[id], prevTotalShares, Math.Rounding.Floor);
            totalAssets[id] = totalAssets[id] - principalRemoved;
            totalShares[id] = prevTotalShares - shares;
        }

        _burn(msg.sender, id, shares);

        // forward received tokens to user and compute first two out amounts for event
        uint256 firstOut = 0;
        uint256 secondOut = 0;
        for (uint256 i = 0; i < toks.length; i++) {
            uint256 afterBal = IERC20(toks[i]).balanceOf(address(this));
            uint256 out = 0;
            if (afterBal > beforeBalances[i]) out = afterBal - beforeBalances[i];
            if (out > 0) IERC20(toks[i]).safeTransfer(msg.sender, out);
            if (i == 0) firstOut = out;
            if (i == 1) secondOut = out;
        }

        emit WithdrawFromStrategy(id, strat, shares, firstOut, secondOut);
    }

    ///////////////////////////////// INTERNAL LOGIC /////////////////////////////////

    function _currentTotalAssets(uint256 id) internal view returns (uint256) {
        // If strategies exist for this asset, sum their reported liquidity
        if (strategies[id].length > 0) {
            uint256 sum = 0;
            for (uint256 i = 0; i < strategies[id].length; i++) {
                address strat = strategies[id][i];
                if (strat != address(0)) {
                    sum += IStrategy(strat).totalAssets();
                }
            }
            return sum;
        }

        // Fallback to single-token pool behavior
        address asset = assetToken[id];
        // @note not supporting native ETH for now
        if (asset == address(0)) return 0;
        return IERC20(asset).balanceOf(address(this));
    }

    // @note inflation attack
    function convertToShares(uint256 id, uint256 assets) public view returns (uint256) {
        return _convertToShares(id, assets, Math.Rounding.Floor);
    }

    function convertToAssets(uint256 id, uint256 shares) public view returns (uint256) {
        return _convertToAssets(id, shares, Math.Rounding.Ceil);
    }

    function _convertToShares(uint256 id, uint256 assets, Math.Rounding rounding) internal view returns (uint256) {
        uint256 _totalShares = totalShares[id];
        uint256 _totalAssets = _currentTotalAssets(id);
        if (_totalShares == 0 || _totalAssets == 0) {
            return assets;
        }
        // anti-donation: add small virtual shares/assets (ERC-4626 style)
        return Math.mulDiv(assets, _totalShares + VIRTUAL_SHARES, _totalAssets + VIRTUAL_ASSETS, rounding);
    }

    function _convertToAssets(uint256 id, uint256 shares, Math.Rounding rounding) internal view returns (uint256) {
        uint256 _totalShares = totalShares[id];
        uint256 _totalAssets = _currentTotalAssets(id);
        require(_totalShares > 0, "No shares exist");
        return Math.mulDiv(shares, _totalAssets + VIRTUAL_ASSETS, _totalShares + VIRTUAL_SHARES, rounding);
    }

    // Small internal wrapper to reduce stack pressure when calling mulDiv from deep functions.
    function _mulDiv(uint256 a, uint256 b, uint256 c, Math.Rounding rounding) internal pure returns (uint256) {
        return Math.mulDiv(a, b, c, rounding);
    }
}
