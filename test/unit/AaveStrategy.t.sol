// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {AaveStrategyV3} from "../../src/strategy/AaveStrategyV3.sol";
import {MockERC20, MockAavePool, MockPoolAddressesProvider} from "../mocks/TestMocks.t.sol";

// Constants
uint256 constant DEFAULT_AMOUNT = 100 ether;
uint256 constant INITIAL_VAULT_BALANCE = 1000 ether;
uint256 constant HALF_AMOUNT = 50 ether;
uint256 constant EXCESS_AMOUNT = 200 ether;
uint256 constant FINAL_EXPECTED_BALANCE = 925 ether;

/// @title AaveStrategyTest
/// @notice Test suite for AaveStrategyV3 contract
contract AaveStrategyTest is Test {
    AaveStrategyV3 public strategy;
    MockAavePool public mockAavePool;
    MockPoolAddressesProvider public mockProvider;
    MockERC20 public mockAsset;

    address public vault;
    address public unauthorizedUser;

    function setUp() public {
        vault = address(this);
        unauthorizedUser = address(0x1);

        _deployMocks();
        _deployStrategy();
        _fundVault();
    }

    // =========================================================================
    // Setup Helpers
    // =========================================================================

    function _deployMocks() private {
        mockAsset = new MockERC20();
        mockAavePool = new MockAavePool();
        mockProvider = new MockPoolAddressesProvider(address(mockAavePool));
    }

    function _deployStrategy() private {
        strategy = new AaveStrategyV3(
            vault,
            address(mockAsset),
            address(mockProvider)
        );
    }

    function _fundVault() private {
        mockAsset.mint(vault, INITIAL_VAULT_BALANCE);
    }

    function _depositToStrategy(uint256 amount) private {
        mockAsset.transfer(address(strategy), amount);
        strategy.deposit(amount);
    }

    // =========================================================================
    // Constructor & Initialization Tests
    // =========================================================================

    function test_Initialize_SetsVaultCorrectly() public view {
        assertEq(strategy.vault(), vault);
    }

    function test_Initialize_SetsAssetCorrectly() public view {
        assertEq(address(strategy.asset()), address(mockAsset));
    }

    function test_Initialize_SetsAavePoolCorrectly() public view {
        assertEq(address(strategy.aavePool()), address(mockAavePool));
    }

    function test_Initialize_SetsATokenCorrectly() public view {
        assertEq(address(strategy.aToken()), address(mockAavePool));
    }

    function test_Constructor_FailsForZeroVaultAddress() public {
        vm.expectRevert("ZERO_VAULT");
        new AaveStrategyV3(address(0), address(mockAsset), address(mockProvider));
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

    function test_Deposit_FailsForZeroAmount() public {
        vm.expectRevert("Amount must be > 0");
        strategy.deposit(0);
    }

    function test_Deposit_SucceedsForValidAmount() public {
        _depositToStrategy(DEFAULT_AMOUNT);

        assertEq(mockAavePool.totalSupplied(), DEFAULT_AMOUNT);
        assertEq(strategy.totalAssets(), DEFAULT_AMOUNT);
    }

    function test_Deposit_MultipleTimes_Accumulates() public {
        _depositToStrategy(50 ether);
        _depositToStrategy(30 ether);
        _depositToStrategy(20 ether);

        assertEq(strategy.totalAssets(), 100 ether);
    }

    // =========================================================================
    // Withdraw Tests
    // =========================================================================

    function test_Withdraw_SucceedsForValidAmount() public {
        _depositToStrategy(DEFAULT_AMOUNT);
        uint256 withdrawn = strategy.withdraw(HALF_AMOUNT);

        assertEq(withdrawn, HALF_AMOUNT);
        assertEq(mockAavePool.totalSupplied(), HALF_AMOUNT);
        assertEq(mockAsset.balanceOf(vault), 950 ether);
    }

    function test_Withdraw_MoreThanBalance_ReturnsAll() public {
        _depositToStrategy(DEFAULT_AMOUNT);
        uint256 withdrawn = strategy.withdraw(EXCESS_AMOUNT);

        assertEq(withdrawn, DEFAULT_AMOUNT);
        assertEq(mockAavePool.totalSupplied(), 0);
    }

    function test_Withdraw_EntireBalance_BecomesZero() public {
        _depositToStrategy(DEFAULT_AMOUNT);
        strategy.withdraw(DEFAULT_AMOUNT);

        assertEq(strategy.totalAssets(), 0);
    }

    // =========================================================================
    // Total Assets Tests
    // =========================================================================

    function test_TotalAssets_InitiallyZero() public view {
        assertEq(strategy.totalAssets(), 0);
    }

    function test_TotalAssets_TracksATokenBalance() public {
        _depositToStrategy(DEFAULT_AMOUNT);
        assertEq(strategy.totalAssets(), DEFAULT_AMOUNT);
    }

    // =========================================================================
    // Integration Tests
    // =========================================================================

    function test_DepositWithdrawCycle_MaintainsCorrectBalances() public {
        _depositToStrategy(DEFAULT_AMOUNT);
        assertEq(strategy.totalAssets(), DEFAULT_AMOUNT);

        _depositToStrategy(HALF_AMOUNT);
        assertEq(strategy.totalAssets(), 150 ether);

        strategy.withdraw(75 ether);
        assertEq(strategy.totalAssets(), 75 ether);
        assertEq(mockAsset.balanceOf(vault), FINAL_EXPECTED_BALANCE);
    }
}
