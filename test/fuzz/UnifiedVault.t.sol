// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {UnifiedVault} from "../../src/core/UnifiedVault.sol";
import {MockERC20, MockStrategy} from "../mocks/TestMocks.t.sol";

/// @title UnifiedVaultFuzzTest
/// @notice Fuzz tests for UnifiedVault contract
contract UnifiedVaultFuzzTest is Test {
    UnifiedVault public vault;
    MockERC20 public asset;
    MockStrategy public strategy;

    address public owner;
    address public user = address(0xF122); // Fuzz user address

    uint256 public constant MAX_FUZZ_AMOUNT = 1000_000 ether; // Cap to prevent overflow issues

    function setUp() public {
        vault = new UnifiedVault();
        owner = vault.owner();

        asset = new MockERC20();
        strategy = new MockStrategy(address(vault), address(asset));

        // Register asset and add strategy
        vm.prank(owner);
        vault.registerAsset(address(asset));

        vm.prank(owner);
        vault.addStrategy(0, address(strategy));

        vm.prank(owner);
        vault.setActiveStrategy(0, 0);
    }

    // =========================================================================
    // FUZZ TEST 1: Deposit-Withdraw Invariant
    // =========================================================================
    /// @notice Fuzz test that verifies: withdraw(deposit(amount)) >= amount
    /// @dev This tests the core invariant that users should never lose principal
    /// @param depositAmount The random amount to deposit (fuzzed input)
    function testFuzz_DepositWithdraw_NeverLosesPrincipal(uint256 depositAmount) public {
        // Constraint: amount must be reasonable
        vm.assume(depositAmount > 0);
        vm.assume(depositAmount <= MAX_FUZZ_AMOUNT);

        // Setup: Give user tokens and approve vault
        asset.mint(user, depositAmount);
        vm.prank(user);
        asset.approve(address(vault), depositAmount);

        // Record initial balance
        uint256 initialBalance = asset.balanceOf(user);

        // User deposits
        vm.prank(user);
        vault.deposit(0, depositAmount);

        // Get shares received (may differ from depositAmount due to virtual shares)
        uint256 shares = vault.balanceOf(user, 0);

        // User withdraws all shares
        vm.prank(user);
        vault.withdraw(0, shares);

        // Final balance check
        uint256 finalBalance = asset.balanceOf(user);

        // INVARIANT: User should receive >= what they deposited
        assertGe(finalBalance, initialBalance - depositAmount);
        assertEq(finalBalance, initialBalance, "Should have all tokens back (1:1 on first deposit)");
    }

    // =========================================================================
    // FUZZ TEST 2: Share Accounting Invariant
    // =========================================================================
    /// @notice Fuzz test that verifies totalShares tracking is accurate
    /// @dev Tests that sum of user balances equals totalShares
    /// @param amount1 First deposit amount
    /// @param amount2 Second deposit amount
    function testFuzz_TotalShares_MatchesUserBalances(uint256 amount1, uint256 amount2) public {
        // Constraint: amounts must be reasonable
        vm.assume(amount1 > 0 && amount1 <= MAX_FUZZ_AMOUNT);
        vm.assume(amount2 > 0 && amount2 <= MAX_FUZZ_AMOUNT);

        address user1 = address(0x1);
        address user2 = address(0x2);

        // User 1 deposits
        asset.mint(user1, amount1);
        vm.prank(user1);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(user1);
        vault.deposit(0, amount1);

        // User 2 deposits
        asset.mint(user2, amount2);
        vm.prank(user2);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(user2);
        vault.deposit(0, amount2);

        // INVARIANT: totalShares should equal sum of individual balances
        uint256 user1Shares = vault.balanceOf(user1, 0);
        uint256 user2Shares = vault.balanceOf(user2, 0);
        uint256 totalShares = vault.totalShares(0);

        assertEq(user1Shares + user2Shares, totalShares, "Total shares mismatch");
    }

    // =========================================================================
    // FUZZ TEST 3: Preview Deposit/Withdraw Consistency
    // =========================================================================
    /// @notice Fuzz test that verifies preview functions match actual conversions
    /// @dev Tests that previewDeposit ≈ actual shares received
    /// @param amount The amount to test
    function testFuzz_PreviewDeposit_MatchesActual(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount <= MAX_FUZZ_AMOUNT);

        asset.mint(user, amount);
        vm.prank(user);
        asset.approve(address(vault), amount);

        // Get preview
        uint256 previewShares = vault.previewDeposit(0, amount);

        // Do actual deposit
        vm.prank(user);
        vault.deposit(0, amount);

        uint256 actualShares = vault.balanceOf(user, 0);

        // INVARIANT: Preview should match actual (allowing for virtual shares difference)
        assertApproxEqRel(previewShares, actualShares, 0.0001e18); // 0.01% tolerance
    }

    // =========================================================================
    // FUZZ TEST 4: Multiple Deposits Don't Break Accounting
    // =========================================================================
    /// @notice Fuzz test with multiple random deposit amounts
    /// @param amount1 First deposit
    /// @param amount2 Second deposit
    /// @param amount3 Third deposit
    function testFuzz_MultipleDeposits_MaintainsInvariants(
        uint256 amount1,
        uint256 amount2,
        uint256 amount3
    ) public {
        vm.assume(amount1 > 0 && amount1 <= MAX_FUZZ_AMOUNT);
        vm.assume(amount2 > 0 && amount2 <= MAX_FUZZ_AMOUNT);
        vm.assume(amount3 > 0 && amount3 <= MAX_FUZZ_AMOUNT);

        // Mint enough tokens
        asset.mint(user, amount1 + amount2 + amount3);
        vm.prank(user);
        asset.approve(address(vault), type(uint256).max);

        // Three sequential deposits
        vm.prank(user);
        vault.deposit(0, amount1);

        vm.prank(user);
        vault.deposit(0, amount2);

        vm.prank(user);
        vault.deposit(0, amount3);

        // INVARIANTS:
        // 1. Total assets should equal sum of deposits
        assertEq(vault.totalAssets(0), amount1 + amount2 + amount3);

        // 2. User shares should reflect ownership (approximately)
        uint256 userShares = vault.balanceOf(user, 0);
        assertGt(userShares, 0);

        // 3. Strategy should hold the assets
        assertEq(strategy.managedAssets(), amount1 + amount2 + amount3);
    }

    // =========================================================================
    // FUZZ TEST 5: Withdraw Never Exceeds User Shares
    // =========================================================================
    /// @notice Fuzz test that verifies withdraw fails when user doesn't have enough shares
    /// @param depositAmount Amount to deposit
    /// @param withdrawShares Shares to try withdrawing (may be more than owned)
    function testFuzz_Withdraw_RevertsWhenInsufficientShares(
        uint256 depositAmount,
        uint256 withdrawShares
    ) public {
        vm.assume(depositAmount > 0 && depositAmount <= MAX_FUZZ_AMOUNT);
        vm.assume(withdrawShares > 0 && withdrawShares <= MAX_FUZZ_AMOUNT);

        // Setup
        asset.mint(user, depositAmount);
        vm.prank(user);
        asset.approve(address(vault), depositAmount);
        vm.prank(user);
        vault.deposit(0, depositAmount);

        uint256 userShares = vault.balanceOf(user, 0);

        // If trying to withdraw more than owned, should fail
        if (withdrawShares > userShares) {
            vm.prank(user);
            vm.expectRevert("Not enough shares");
            vault.withdraw(0, withdrawShares);
        } else {
            // Should succeed
            vm.prank(user);
            vault.withdraw(0, withdrawShares);
        }
    }

    // =========================================================================
    // FUZZ TEST 6: Zero Amount Rejections
    // =========================================================================
    /// @notice Fuzz test that verifies zero deposits are rejected
    /// @param amount Random amount (should include zero)
    function testFuzz_Deposit_ZeroAmountFails(uint256 amount) public {
        // Only test the zero case explicitly
        if (amount == 0) {
            vm.prank(user);
            vm.expectRevert("Amount must be > 0");
            vault.deposit(0, 0);
        }
    }

    // =========================================================================
    // FUZZ TEST 7: Round-Trip Invariant (Advanced)
    // =========================================================================
    /// @notice Tests that deposit → withdraw → deposit → withdraw preserves solvency
    /// @param amount1 First round-trip amount
    /// @param amount2 Second round-trip amount
    function testFuzz_RoundTrip_PreservesAccounting(uint256 amount1, uint256 amount2) public {
        vm.assume(amount1 > 0 && amount1 <= MAX_FUZZ_AMOUNT);
        vm.assume(amount2 > 0 && amount2 <= MAX_FUZZ_AMOUNT);

        address user1 = address(0xAAA);
        address user2 = address(0xBBB);

        // User 1 round-trip
        asset.mint(user1, amount1);
        vm.prank(user1);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(user1);
        vault.deposit(0, amount1);

        uint256 shares1 = vault.balanceOf(user1, 0);
        vm.prank(user1);
        vault.withdraw(0, shares1);

        // User 2 round-trip
        asset.mint(user2, amount2);
        vm.prank(user2);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(user2);
        vault.deposit(0, amount2);

        uint256 shares2 = vault.balanceOf(user2, 0);
        vm.prank(user2);
        vault.withdraw(0, shares2);

        // After all withdrawals, vault should be empty
        assertEq(vault.totalShares(0), 0, "Shares should be zero");
        assertEq(vault.totalAssets(0), 0, "Assets should be zero");
        assertEq(strategy.managedAssets(), 0, "Strategy should be empty");
    }
}
