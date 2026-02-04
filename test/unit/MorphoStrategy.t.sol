// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {MorphoStrategy} from "../../src/strategy/MorphoStrategy.sol";
import {IMorpho} from "../../src/interfaces/IMorpho.sol";
import {MockERC20, MockMorpho} from "../mocks/TestMocks.t.sol";

// Constants
uint256 constant DEFAULT_AMOUNT = 100 ether;
uint256 constant INITIAL_VAULT_BALANCE = 1000 ether;
uint256 constant HALF_AMOUNT = 50 ether;
uint256 constant EXCESS_AMOUNT = 200 ether;

/// @title MorphoStrategyTest
/// @notice Test suite for MorphoStrategy contract
contract MorphoStrategyTest is Test {
    MorphoStrategy public strategy;
    MockMorpho public mockMorpho;
    MockERC20 public mockAsset;

    address public vault;
    address public unauthorizedUser;

    IMorpho.MarketParams public marketParams;

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
        mockMorpho = new MockMorpho();

        marketParams = IMorpho.MarketParams({
            loanToken: address(mockAsset),
            collateralToken: address(0x2),
            oracle: address(0x3),
            irm: address(0x4),
            lltv: address(0x5)
        });
    }

    function _deployStrategy() private {
        strategy = new MorphoStrategy(
            vault,
            address(mockAsset),
            address(mockMorpho),
            marketParams.loanToken,
            marketParams.collateralToken,
            marketParams.oracle,
            marketParams.irm,
            marketParams.lltv
        );
    }

    function _fundVault() private {
        mockAsset.mint(vault, INITIAL_VAULT_BALANCE);
    }

    function _depositToStrategy(uint256 amount) private {
        mockAsset.approve(address(strategy), amount);
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

    function test_Initialize_SetsMorphoCorrectly() public view {
        assertEq(address(strategy.morpho()), address(mockMorpho));
    }

    function test_Initialize_SetsMarketParamsCorrectly() public view {
        (
            address loanToken_,
            address collateralToken_,
            address oracle_,
            address irm_,
            address lltv_
        ) = strategy.marketParams();

        assertEq(loanToken_, marketParams.loanToken);
        assertEq(collateralToken_, marketParams.collateralToken);
        assertEq(oracle_, marketParams.oracle);
        assertEq(irm_, marketParams.irm);
        assertEq(lltv_, marketParams.lltv);
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
        assertEq(mockMorpho.totalSupplied(), DEFAULT_AMOUNT);
    }

    function test_Deposit_MultipleTimes_Accumulates() public {
        mockAsset.approve(address(strategy), type(uint256).max);

        _depositToStrategy(DEFAULT_AMOUNT);
        _depositToStrategy(HALF_AMOUNT);
        _depositToStrategy(25 ether);

        assertEq(strategy.totalAssets(), 175 ether);
    }

    // =========================================================================
    // Withdraw Tests
    // =========================================================================

    function test_Withdraw_SucceedsForValidAmount() public {
        _depositToStrategy(DEFAULT_AMOUNT);
        uint256 withdrawn = strategy.withdraw(HALF_AMOUNT);

        assertEq(withdrawn, HALF_AMOUNT);
        assertEq(mockMorpho.totalSupplied(), HALF_AMOUNT);
    }

    function test_Withdraw_MoreThanBalance_ReturnsAll() public {
        _depositToStrategy(DEFAULT_AMOUNT);
        uint256 withdrawn = strategy.withdraw(EXCESS_AMOUNT);

        assertEq(withdrawn, DEFAULT_AMOUNT);
        assertEq(mockMorpho.totalSupplied(), 0);
    }

    // =========================================================================
    // Total Assets Tests
    // =========================================================================

    function test_TotalAssets_InitiallyZero() public view {
        assertEq(strategy.totalAssets(), 0);
    }

    function test_TotalAssets_TracksDeposits() public {
        _depositToStrategy(DEFAULT_AMOUNT);
        assertEq(strategy.totalAssets(), DEFAULT_AMOUNT);
    }

    // =========================================================================
    // Integration Tests
    // =========================================================================

    function test_DepositWithdrawCycle_MaintainsCorrectBalance() public {
        mockAsset.approve(address(strategy), type(uint256).max);

        _depositToStrategy(DEFAULT_AMOUNT);
        assertEq(strategy.totalAssets(), DEFAULT_AMOUNT);

        _depositToStrategy(HALF_AMOUNT);
        assertEq(strategy.totalAssets(), 150 ether);

        strategy.withdraw(75 ether);
        assertEq(strategy.totalAssets(), 75 ether);
    }
}
