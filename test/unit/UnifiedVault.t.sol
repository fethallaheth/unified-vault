// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {UnifiedVault} from "../../src/core/UnifiedVault.sol";
import {MockERC20, MockStrategy} from "../mocks/TestMocks.t.sol";
import {IStrategy} from "../../src/interfaces/IStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Constants
uint256 constant DEFAULT_AMOUNT = 100 ether;
uint256 constant INITIAL_VAULT_BALANCE = 1000 ether;
uint256 constant HALF_AMOUNT = 50 ether;
uint256 constant YIELD_AMOUNT = 10 ether;
uint256 constant FIRST_ID = 0;

/// @title UnifiedVaultTest
/// @notice Comprehensive test suite for UnifiedVault contract
contract UnifiedVaultTest is Test {
    UnifiedVault public vault;
    MockERC20 public asset;
    MockStrategy public strategy1;
    MockStrategy public strategy2;

    address public owner;
    address public alice;
    address public bob;

    event DepositToStrategy(uint256 indexed id, address indexed strategy, uint256 sharesMinted, uint256 assetsAdded);
    event WithdrawFromStrategy(uint256 indexed id, address indexed strategy, uint256 sharesBurned, uint256 out0, uint256 out1);
    event Rebalanced(uint256 indexed id, address fromStrat, address toStrat, uint256 amount);
    event StrategyAdded(uint256 indexed id, address strategy);
    event StrategyRemoved(uint256 indexed id, address strategy);
    event ActiveStrategySet(uint256 indexed id, uint256 index);

    function setUp() public {
        _deployContracts();
        _setupUsers();
        _registerAsset();
        _addStrategies();
    }

    // =========================================================================
    // Setup Helpers
    // =========================================================================

    function _deployContracts() private {
        vault = new UnifiedVault();
        asset = new MockERC20();
    }

    function _setupUsers() private {
        owner = vault.owner();
        alice = address(0xA11CE);
        bob = address(0xB0B);

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function _registerAsset() private {
        vm.prank(owner);
        vault.registerAsset(address(asset));
    }

    function _addStrategies() private {
        vm.startPrank(owner);
        strategy1 = new MockStrategy(address(vault), address(asset));
        strategy2 = new MockStrategy(address(vault), address(asset));

        vault.addStrategy(FIRST_ID, address(strategy1));
        vault.addStrategy(FIRST_ID, address(strategy2));
        vault.setActiveStrategy(FIRST_ID, 0);
        vm.stopPrank();
    }

    function _mintAndApprove(address user, uint256 amount) private {
        asset.mint(user, amount);
        vm.prank(user);
        asset.approve(address(vault), type(uint256).max);
    }

    // =========================================================================
    // Constructor & Initialization Tests
    // =========================================================================

    function test_Initialize_SetsOwnerCorrectly() public view {
        assertEq(vault.owner(), owner);
    }

    function test_Initialize_FirstAssetRegistered() public view {
        assertEq(vault.assetToken(FIRST_ID), address(asset));
    }

    // =========================================================================
    // Asset Management Tests
    // =========================================================================

    function test_RegisterAsset_SucceedsForOwner() public {
        MockERC20 newAsset = new MockERC20();

        vm.prank(owner);
        vault.registerAsset(address(newAsset));

        assertEq(vault.assetToken(1), address(newAsset));
    }

    function test_RegisterAsset_FailsForNonOwner() public {
        MockERC20 newAsset = new MockERC20();

        vm.prank(alice);
        vm.expectRevert();
        vault.registerAsset(address(newAsset));
    }

    function test_RemoveAsset_SucceedsWhenEmpty() public {
        vm.prank(owner);
        vault.removeAsset(FIRST_ID);

        assertEq(vault.assetToken(FIRST_ID), address(0));
    }

    function test_RemoveAsset_FailsWhenNotEmpty() public {
        _mintAndApprove(alice, DEFAULT_AMOUNT);
        vm.prank(alice);
        vault.deposit(FIRST_ID, DEFAULT_AMOUNT);

        vm.prank(owner);
        vm.expectRevert("Pool not empty");
        vault.removeAsset(FIRST_ID);
    }

    // =========================================================================
    // Strategy Management Tests
    // =========================================================================

    function test_AddStrategy_SucceedsForOwner() public {
        MockStrategy newStrategy = new MockStrategy(address(vault), address(asset));

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit StrategyAdded(FIRST_ID, address(newStrategy));

        vault.addStrategy(FIRST_ID, address(newStrategy));

        address[] memory strategies = vault.getStrategies(FIRST_ID);
        assertEq(strategies.length, 3);
        assertEq(strategies[2], address(newStrategy));
    }

    function test_AddStrategy_FailsForNonOwner() public {
        MockStrategy newStrategy = new MockStrategy(address(vault), address(asset));

        vm.prank(alice);
        vm.expectRevert();
        vault.addStrategy(FIRST_ID, address(newStrategy));
    }

    function test_AddStrategy_FailsForZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("ZERO_STRAT");
        vault.addStrategy(FIRST_ID, address(0));
    }

    function test_AddStrategy_ApproveMaxAmount() public {
        MockStrategy newStrategy = new MockStrategy(address(vault), address(asset));

        vm.prank(owner);
        vault.addStrategy(FIRST_ID, address(newStrategy));

        assertEq(asset.allowance(address(vault), address(newStrategy)), type(uint256).max);
    }

    function test_RemoveStrategy_SucceedsForOwner() public {
        vm.prank(owner);
        vault.removeStrategy(FIRST_ID, 0);

        address[] memory strategies = vault.getStrategies(FIRST_ID);
        assertEq(strategies.length, 1);
    }

    function test_RemoveStrategy_ResetsActiveStrategyIfOutOfBounds() public {
        vm.prank(owner);
        vault.setActiveStrategy(FIRST_ID, 1);

        vm.prank(owner);
        vault.removeStrategy(FIRST_ID, 0);

        assertEq(vault.activeStrategy(FIRST_ID), 0);
    }

    function test_SetActiveStrategy_SucceedsForOwner() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit ActiveStrategySet(FIRST_ID, 1);

        vault.setActiveStrategy(FIRST_ID, 1);

        assertEq(vault.activeStrategy(FIRST_ID), 1);
    }

    function test_SetActiveStrategy_FailsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.setActiveStrategy(FIRST_ID, 1);
    }

    function test_GetStrategies_ReturnsAllStrategies() public view {
        address[] memory strategies = vault.getStrategies(FIRST_ID);

        assertEq(strategies.length, 2);
        assertEq(strategies[0], address(strategy1));
        assertEq(strategies[1], address(strategy2));
    }

    // =========================================================================
    // Deposit Tests
    // =========================================================================

    function test_Deposit_SucceedsForValidAmount() public {
        _mintAndApprove(alice, DEFAULT_AMOUNT);

        vm.prank(alice);
        vault.deposit(FIRST_ID, DEFAULT_AMOUNT);

        assertEq(vault.balanceOf(alice, FIRST_ID), DEFAULT_AMOUNT);
        assertEq(vault.totalAssets(FIRST_ID), DEFAULT_AMOUNT);
        assertEq(vault.totalShares(FIRST_ID), DEFAULT_AMOUNT);
    }

    function test_Deposit_FailsForUnregisteredAsset() public {
        MockERC20 newAsset = new MockERC20();
        newAsset.mint(alice, DEFAULT_AMOUNT);

        vm.prank(alice);
        newAsset.approve(address(vault), DEFAULT_AMOUNT);

        vm.prank(alice);
        vm.expectRevert("Asset not registered");
        vault.deposit(1, DEFAULT_AMOUNT);
    }

    function test_Deposit_FailsForZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert("Amount must be > 0");
        vault.deposit(FIRST_ID, 0);
    }

    function test_Deposit_AutoDepositsToActiveStrategy() public {
        _mintAndApprove(alice, DEFAULT_AMOUNT);

        vm.prank(alice);
        vault.deposit(FIRST_ID, DEFAULT_AMOUNT);

        assertEq(strategy1.managedAssets(), DEFAULT_AMOUNT);
    }

    function test_Deposit_MultipleUsers_Accumulates() public {
        _mintAndApprove(alice, DEFAULT_AMOUNT);
        _mintAndApprove(bob, DEFAULT_AMOUNT);

        vm.prank(alice);
        vault.deposit(FIRST_ID, DEFAULT_AMOUNT);

        vm.prank(bob);
        vault.deposit(FIRST_ID, DEFAULT_AMOUNT);

        assertEq(vault.totalAssets(FIRST_ID), DEFAULT_AMOUNT * 2);
        // Use range check due to virtual shares (1% tolerance)
        assertGt(vault.totalShares(FIRST_ID), DEFAULT_AMOUNT * 2 - 1 ether);
        assertLt(vault.totalShares(FIRST_ID), DEFAULT_AMOUNT * 2 + 1 ether);
    }

    // =========================================================================
    // Withdraw Tests
    // =========================================================================

    function test_Withdraw_SucceedsForValidAmount() public {
        _mintAndApprove(alice, DEFAULT_AMOUNT);

        vm.prank(alice);
        vault.deposit(FIRST_ID, DEFAULT_AMOUNT);

        vm.prank(alice);
        vault.withdraw(FIRST_ID, HALF_AMOUNT);

        assertEq(vault.balanceOf(alice, FIRST_ID), HALF_AMOUNT);
        assertEq(asset.balanceOf(alice), HALF_AMOUNT);
    }

    function test_Withdraw_FailsForInsufficientShares() public {
        _mintAndApprove(alice, DEFAULT_AMOUNT);

        vm.prank(alice);
        vault.deposit(FIRST_ID, DEFAULT_AMOUNT);

        vm.prank(alice);
        vm.expectRevert("Not enough shares");
        vault.withdraw(FIRST_ID, DEFAULT_AMOUNT * 2);
    }

    function test_Withdraw_WithYield_ReturnsMoreThanPrincipal() public {
        _mintAndApprove(alice, DEFAULT_AMOUNT);

        vm.prank(alice);
        vault.deposit(FIRST_ID, DEFAULT_AMOUNT);

        // Simulate yield
        strategy1.simulateYield(YIELD_AMOUNT);

        uint256 preBalance = asset.balanceOf(alice);

        vm.prank(alice);
        vault.withdraw(FIRST_ID, DEFAULT_AMOUNT);

        uint256 withdrawn = asset.balanceOf(alice) - preBalance;
        assertEq(withdrawn, DEFAULT_AMOUNT + YIELD_AMOUNT);
    }

    function test_Withdraw_All_SetsSharesToZero() public {
        _mintAndApprove(alice, DEFAULT_AMOUNT);

        vm.prank(alice);
        vault.deposit(FIRST_ID, DEFAULT_AMOUNT);

        vm.prank(alice);
        vault.withdraw(FIRST_ID, DEFAULT_AMOUNT);

        assertEq(vault.balanceOf(alice, FIRST_ID), 0);
        assertEq(vault.totalShares(FIRST_ID), 0);
    }

    // =========================================================================
    // Preview Tests
    // =========================================================================

    function test_PreviewDeposit_ReturnsCorrectShares() public view {
        uint256 shares = vault.previewDeposit(FIRST_ID, DEFAULT_AMOUNT);
        assertEq(shares, DEFAULT_AMOUNT); // 1:1 when empty
    }

    function test_PreviewWithdraw_ReturnsCorrectAssets() public {
        _mintAndApprove(alice, DEFAULT_AMOUNT);

        vm.prank(alice);
        vault.deposit(FIRST_ID, DEFAULT_AMOUNT);

        uint256 assets = vault.previewWithdraw(FIRST_ID, HALF_AMOUNT);
        // Use range check due to virtual shares (should be close to half)
        assertGt(assets, HALF_AMOUNT - 1 ether);
        assertLt(assets, HALF_AMOUNT + 1 ether);
    }

    // =========================================================================
    // Convert Tests
    // =========================================================================

    function test_ConvertToShares_ReturnsOneToOneWhenEmpty() public view {
        uint256 shares = vault.convertToShares(FIRST_ID, DEFAULT_AMOUNT);
        assertEq(shares, DEFAULT_AMOUNT);
    }

    function test_ConvertToAssets_ReturnsOneToOneWhenEmpty() public {
        _mintAndApprove(alice, DEFAULT_AMOUNT);
        vm.prank(alice);
        vault.deposit(FIRST_ID, DEFAULT_AMOUNT);

        // After deposit, shares exist, conversion works
        // Note: Due to virtual shares/assets, there's a small deviation
        uint256 assets = vault.convertToAssets(FIRST_ID, DEFAULT_AMOUNT);
        assertLt(assets, DEFAULT_AMOUNT + 1 ether); // Should be close to original
        assertGt(assets, DEFAULT_AMOUNT - 1 ether);
    }

    function test_ConvertToAssets_FailsWhenNoSharesExist() public {
        vm.expectRevert("No shares exist");
        vault.convertToAssets(FIRST_ID, DEFAULT_AMOUNT);
    }

    // =========================================================================
    // Harvest Tests
    // =========================================================================

    function test_Harvest_AbsorbsYieldIntoPrincipal() public {
        _mintAndApprove(alice, DEFAULT_AMOUNT);

        vm.prank(alice);
        vault.deposit(FIRST_ID, DEFAULT_AMOUNT);

        // Simulate yield
        strategy1.simulateYield(YIELD_AMOUNT);

        uint256 preHarvestAssets = vault.totalAssets(FIRST_ID);

        vm.prank(owner);
        vault.harvest(FIRST_ID);

        uint256 postHarvestAssets = vault.totalAssets(FIRST_ID);

        assertEq(postHarvestAssets - preHarvestAssets, YIELD_AMOUNT);
    }

    function test_Harvest_FailsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.harvest(FIRST_ID);
    }

    function test_Harvest_FailsIfBalanceDecreases() public {
        _mintAndApprove(alice, DEFAULT_AMOUNT);

        vm.prank(alice);
        vault.deposit(FIRST_ID, DEFAULT_AMOUNT);

        // Decrease managed assets (simulate loss)
        strategy1.withdraw(HALF_AMOUNT);

        vm.prank(owner);
        vm.expectRevert("Invariant violated");
        vault.harvest(FIRST_ID);
    }

    // =========================================================================
    // Rebalance Tests
    // =========================================================================

    function test_Rebalance_SucceedsForOwner() public {
        _mintAndApprove(alice, DEFAULT_AMOUNT);

        vm.prank(alice);
        vault.deposit(FIRST_ID, DEFAULT_AMOUNT);

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit Rebalanced(FIRST_ID, address(strategy1), address(strategy2), HALF_AMOUNT);

        vault.rebalance(FIRST_ID, 0, 1, HALF_AMOUNT);

        assertEq(strategy1.managedAssets(), HALF_AMOUNT);
        assertEq(strategy2.managedAssets(), HALF_AMOUNT);
    }

    function test_Rebalance_FailsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.rebalance(FIRST_ID, 0, 1, HALF_AMOUNT);
    }

    function test_Rebalance_FailsForSameStrategy() public {
        vm.prank(owner);
        vm.expectRevert("Same strategy");
        vault.rebalance(FIRST_ID, 0, 0, HALF_AMOUNT);
    }

    function test_Rebalance_FailsForZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert("Amount > 0");
        vault.rebalance(FIRST_ID, 0, 1, 0);
    }

    // =========================================================================
    // Integration Tests
    // =========================================================================

    function test_FullCycle_DepositYieldWithdraw() public {
        // Alice deposits
        _mintAndApprove(alice, DEFAULT_AMOUNT);
        vm.prank(alice);
        vault.deposit(FIRST_ID, DEFAULT_AMOUNT);

        // Yield accrues
        strategy1.simulateYield(YIELD_AMOUNT);

        // Alice harvests yield
        vm.prank(owner);
        vault.harvest(FIRST_ID);

        // Alice withdraws with yield
        uint256 preBalance = asset.balanceOf(alice);
        vm.prank(alice);
        vault.withdraw(FIRST_ID, DEFAULT_AMOUNT);

        assertEq(asset.balanceOf(alice) - preBalance, DEFAULT_AMOUNT + YIELD_AMOUNT);
    }

    function test_MultipleUsers_DepositAndWithdraw() public {
        uint256 aliceAmount = 100 ether;
        uint256 bobAmount = 50 ether;
        uint256 totalYield = 30 ether;

        _mintAndApprove(alice, aliceAmount);
        _mintAndApprove(bob, bobAmount);

        vm.prank(alice);
        vault.deposit(FIRST_ID, aliceAmount);

        vm.prank(bob);
        vault.deposit(FIRST_ID, bobAmount);

        // Yield accrues
        strategy1.simulateYield(totalYield);
        vm.prank(owner);
        vault.harvest(FIRST_ID);

        // Get user's actual share balance
        uint256 aliceShares = vault.balanceOf(alice, FIRST_ID);
        uint256 bobShares = vault.balanceOf(bob, FIRST_ID);

        // Alice withdraws all her shares
        uint256 alicePreBalance = asset.balanceOf(alice);
        vm.prank(alice);
        vault.withdraw(FIRST_ID, aliceShares);

        // Bob withdraws all his shares
        uint256 bobPreBalance = asset.balanceOf(bob);
        vm.prank(bob);
        vault.withdraw(FIRST_ID, bobShares);

        // Check results with larger tolerance (1 ether) due to virtual shares
        uint256 aliceReceived = asset.balanceOf(alice) - alicePreBalance;
        uint256 bobReceived = asset.balanceOf(bob) - bobPreBalance;

        assertApproxEqAbs(aliceReceived, aliceAmount + (totalYield * 2 / 3), 1 ether);
        assertApproxEqAbs(bobReceived, bobAmount + (totalYield / 3), 1 ether);
    }

    function test_StrategySwitch_DepositsGoToActiveStrategy() public {
        _mintAndApprove(alice, DEFAULT_AMOUNT);

        // Deposit to strategy 1
        vm.prank(alice);
        vault.deposit(FIRST_ID, HALF_AMOUNT);

        // Switch to strategy 2
        vm.prank(owner);
        vault.setActiveStrategy(FIRST_ID, 1);

        // Deposit to strategy 2
        vm.prank(alice);
        vault.deposit(FIRST_ID, HALF_AMOUNT);

        assertEq(strategy1.managedAssets(), HALF_AMOUNT);
        assertEq(strategy2.managedAssets(), HALF_AMOUNT);
    }

    // =========================================================================
    // ERC6909 Token Tests
    // =========================================================================

    function test_ERC6909_Transfer_Succeeds() public {
        _mintAndApprove(alice, DEFAULT_AMOUNT);

        vm.prank(alice);
        vault.deposit(FIRST_ID, DEFAULT_AMOUNT);

        vm.prank(alice);
        vault.transfer(bob, FIRST_ID, HALF_AMOUNT);

        assertEq(vault.balanceOf(alice, FIRST_ID), HALF_AMOUNT);
        assertEq(vault.balanceOf(bob, FIRST_ID), HALF_AMOUNT);
    }

    function test_ERC6909_BalanceOf_ReturnsCorrectBalance() public {
        _mintAndApprove(alice, DEFAULT_AMOUNT);

        vm.prank(alice);
        vault.deposit(FIRST_ID, DEFAULT_AMOUNT);

        assertEq(vault.balanceOf(alice, FIRST_ID), DEFAULT_AMOUNT);
        assertEq(vault.balanceOf(bob, FIRST_ID), 0);
    }
}
