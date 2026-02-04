// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {BaseStrategy} from "../../src/strategy/Base/BaseStrategy.sol";

// Constants
uint256 constant DEFAULT_AMOUNT = 100 ether;
uint256 constant INITIAL_VAULT_BALANCE = 1000 ether;

/// @title MockStrategy
/// @notice Minimal strategy implementation for testing BaseStrategy
contract MockStrategy is BaseStrategy {
    uint256 public assets;

    constructor(address _vault) BaseStrategy(_vault) {}

    function deposit(uint256 amount) external override onlyVault {
        assets += amount;
    }

    function withdraw(uint256 amount) external override onlyVault returns (uint256) {
        if (amount > assets) amount = assets;
        assets -= amount;
        return amount;
    }

    function totalAssets() external view override returns (uint256) {
        return assets;
    }
}

/// @title BaseStrategyTest
/// @notice Test suite for BaseStrategy abstract contract
contract BaseStrategyTest is Test {
    MockStrategy public strategy;
    address public vault;
    address public unauthorizedUser;

    function setUp() public {
        vault = address(this);
        strategy = new MockStrategy(vault);
        unauthorizedUser = address(0x1);
    }

    // =========================================================================
    // Constructor Tests
    // =========================================================================

    function test_Initialize_SetsVaultCorrectly() public view {
        assertEq(strategy.vault(), vault);
    }

    function test_Constructor_RejectZeroAddress() public {
        vm.expectRevert("ZERO_VAULT");
        new MockStrategy(address(0));
    }

    // =========================================================================
    // Access Control Tests
    // =========================================================================

    function test_Deposit_FailsWhenCallerIsNotVault() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert("NOT_VAULT");
        strategy.deposit(DEFAULT_AMOUNT);
    }

    function test_Withdraw_FailsWhenCallerIsNotVault() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert("NOT_VAULT");
        strategy.withdraw(DEFAULT_AMOUNT);
    }

    // =========================================================================
    // Deposit Tests
    // =========================================================================

    function test_Deposit_IncreasesAssetBalance() public {
        strategy.deposit(DEFAULT_AMOUNT);
        assertEq(strategy.totalAssets(), DEFAULT_AMOUNT);
    }

    function test_Deposit_MultipleTimes_Accumulates() public {
        strategy.deposit(DEFAULT_AMOUNT);
        strategy.deposit(50 ether);
        strategy.deposit(25 ether);
        assertEq(strategy.totalAssets(), 175 ether);
    }

    // =========================================================================
    // Withdraw Tests
    // =========================================================================

    function test_Withdraw_DecreasesAssetBalance() public {
        strategy.deposit(DEFAULT_AMOUNT);
        uint256 withdrawn = strategy.withdraw(50 ether);

        assertEq(withdrawn, 50 ether);
        assertEq(strategy.totalAssets(), 50 ether);
    }

    function test_Withdraw_MoreThanBalance_ReturnsAll() public {
        strategy.deposit(DEFAULT_AMOUNT);
        uint256 withdrawn = strategy.withdraw(150 ether);

        assertEq(withdrawn, DEFAULT_AMOUNT);
        assertEq(strategy.totalAssets(), 0);
    }

    function test_Withdraw_EntireBalance_BecomesZero() public {
        strategy.deposit(DEFAULT_AMOUNT);
        strategy.withdraw(DEFAULT_AMOUNT);
        assertEq(strategy.totalAssets(), 0);
    }

    // =========================================================================
    // Total Assets Tests
    // =========================================================================

    function test_TotalAssets_InitiallyZero() public view {
        assertEq(strategy.totalAssets(), 0);
    }

    // =========================================================================
    // Integration Tests
    // =========================================================================

    function test_DepositWithdrawCycle_MaintainsCorrectBalance() public {
        // Initial deposit
        strategy.deposit(INITIAL_VAULT_BALANCE);
        assertEq(strategy.totalAssets(), INITIAL_VAULT_BALANCE);

        // Partial withdrawal
        strategy.withdraw(300 ether);
        assertEq(strategy.totalAssets(), 700 ether);

        // Additional deposit
        strategy.deposit(200 ether);
        assertEq(strategy.totalAssets(), 900 ether);

        // Full withdrawal
        strategy.withdraw(900 ether);
        assertEq(strategy.totalAssets(), 0);
    }
}
