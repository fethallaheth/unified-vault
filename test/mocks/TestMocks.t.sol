// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IMorpho} from "../../src/interfaces/IMorpho.sol";
import {IAavePool} from "../../src/interfaces/IAavePool.sol";
import {IPoolAddressesProvider} from "../../src/interfaces/IPoolAddressesProvider.sol";
import {IStrategy} from "../../src/interfaces/IStrategy.sol";

/// @title MockERC20
/// @notice Standard ERC20 mock for testing
contract MockERC20 is IERC20 {
    string public name = "Mock Token";
    string public symbol = "MOCK";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/// @title MockMorpho
/// @notice Mock Morpho protocol for testing
contract MockMorpho is IMorpho {
    uint256 public totalSupplied;
    uint256 public shares;

    function supply(MarketParams calldata, uint256 assets, address, bytes calldata) external override {
        totalSupplied += assets;
        shares += assets;
    }

    function withdraw(MarketParams calldata, uint256 assets, address, address) external override returns (uint256) {
        if (assets > totalSupplied) assets = totalSupplied;
        totalSupplied -= assets;
        shares -= assets;
        return assets;
    }

    function balanceOf(MarketParams calldata, address) external view override returns (uint256) {
        return shares;
    }

    function convertToAssets(MarketParams calldata, uint256 _shares) external view override returns (uint256) {
        return _shares;
    }
}

/// @title MockAavePool
/// @notice Mock Aave V3 pool that also implements IERC20 as aToken
contract MockAavePool is IAavePool, IERC20 {
    uint256 public totalSupplied;
    mapping(address => uint256) public balanceOf;

    function supply(address, uint256 amount, address onBehalfOf, uint16) external override {
        totalSupplied += amount;
        balanceOf[onBehalfOf] += amount;
    }

    function withdraw(address, uint256 amount, address) external override returns (uint256) {
        if (amount > totalSupplied) amount = totalSupplied;
        totalSupplied -= amount;
        balanceOf[msg.sender] -= amount;
        return amount;
    }

    function getReserveData(address) external view override returns (ReserveData memory) {
        ReserveData memory data;
        data.aTokenAddress = address(this);
        return data;
    }

    // IERC20 implementation (as aToken)
    string public name = "Mock AToken";
    string public symbol = "maToken";
    uint8 public decimals = 18;
    uint256 public override totalSupply;
    mapping(address => mapping(address => uint256)) public override allowance;

    function transfer(address to, uint256 amount) external override returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/// @title MockPoolAddressesProvider
/// @notice Mock Aave pool addresses provider
contract MockPoolAddressesProvider is IPoolAddressesProvider {
    address public pool;

    constructor(address _pool) {
        pool = _pool;
    }

    function getPool() external view override returns (address) {
        return pool;
    }
}

/// @title MockStrategy
/// @notice Mock strategy for testing UnifiedVault
contract MockStrategy is IStrategy {
    using SafeERC20 for IERC20;

    address public immutable vault;
    IERC20 public immutable asset;
    uint256 public managedAssets;

    event Deposited(uint256 amount);
    event Withdrawn(uint256 amount);

    constructor(address _vault, address _asset) {
        vault = _vault;
        asset = IERC20(_asset);
    }

    function deposit(uint256 amount) external override {
        // Pull tokens from vault (vault has already approved)
        asset.safeTransferFrom(vault, address(this), amount);
        managedAssets += amount;
        emit Deposited(amount);
    }

    function withdraw(uint256 amount) external override returns (uint256) {
        if (amount > managedAssets) amount = managedAssets;
        managedAssets -= amount;
        asset.safeTransfer(msg.sender, amount);
        emit Withdrawn(amount);
        return amount;
    }

    function totalAssets() external view override returns (uint256) {
        return managedAssets;
    }

    // Helper to simulate yield generation
    function simulateYield(uint256 amount) external {
        // Mint tokens to simulate yield
        MockERC20(address(asset)).mint(address(this), amount);
        managedAssets += amount;
    }
}
