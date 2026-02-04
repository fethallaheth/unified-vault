# Unified Vault - Codebase Documentation

## Project Overview

**Unified Vault** is a modular, off-chain managed yield aggregator built on the **ERC-6909** multi-token standard. It enables users to deposit assets into a single vault while an off-chain "Allocator" bot automatically optimizes yields across multiple DeFi protocols (Aave, Morpho, etc.).

### Key Design Philosophy
- **Separation of Concerns**: Accounting layer (Vault) is separated from execution layer (Strategies)
- **Off-Chain Management**: Rebalancing decisions are made off-chain to save gas
- **Modular Strategies**: New protocols can be added without modifying the core vault
- **ERC-6909 Standard**: Multi-token support where each asset gets a unique Token ID

---

## Directory Structure

```
unified-vault/
├── src/
│   ├── core/
│   │   └── UnifiedVault.sol          # Main vault contract (ERC-6909)
│   ├── strategy/
│   │   ├── Base/
│   │   │   └── BaseStrategy.sol      # Abstract base for all strategies
│   │   ├── AaveStrategyV3.sol        # Aave V3 protocol wrapper
│   │   └── MorphoStrategy.sol        # Morpho protocol wrapper
│   ├── interfaces/
│   │   ├── IStrategy.sol             # Strategy interface
│   │   ├── IAavePool.sol             # Aave V3 pool interface
│   │   ├── IPoolAddressesProvider.sol # Aave addresses provider
│   │   └── IMorpho.sol               # Morpho protocol interface
│   └── libraries/
│       └── errors.sol                # Error library (currently empty)
├── foundry.toml                      # Foundry configuration
├── README.md                         # User-facing documentation
└── lib/                              # Dependencies (forge-std, openzeppelin)
```

---

## Core Contracts

### UnifiedVault.sol

**Location**: `src/core/UnifiedVault.sol`

**Inheritance**: `ERC6909`, `Ownable`

**Purpose**: Central vault that handles user deposits, share accounting, and fund routing to strategies.

#### Key State Variables

```solidity
uint256[] public Ids                                // Array of registered asset IDs
mapping(uint256 => uint256) public totalAssets      // Total assets per ID
mapping(uint256 => uint256) public totalShares      // Total shares per ID
mapping(uint256 => address) public assetToken       // Asset address per ID

// Strategy management
mapping(uint256 => address[]) public strategies     // All strategies for an asset
mapping(uint256 => uint256) public activeStrategy   // Currently active strategy index

// Anti-donation protection (ERC-4626 style)
uint256 internal constant VIRTUAL_SHARES = 10 ** 18
uint256 internal constant VIRTUAL_ASSETS = 1
```

#### Key Functions

| Function | Access | Description |
|----------|--------|-------------|
| `deposit(uint256 id, uint256 assets)` | external | Deposit assets, mint shares, route to active strategy |
| `withdraw(uint256 id, uint256 shares)` | external | Burn shares, return assets (+ yield) |
| `previewDeposit(id, assets)` | view | Calculate shares for deposit |
| `previewWithdraw(id, shares)` | view | Calculate assets for withdrawal |
| `harvest(uint256 id)` | onlyOwner | Absorb yield into principal |
| `registerAsset(address asset)` | onlyOwner | Add new supported asset |
| `removeAsset(uint256 id)` | onlyOwner | Remove asset (must be empty) |
| `addStrategy(id, strategy)` | onlyOwner | Add strategy for an asset |
| `removeStrategy(id, index)` | onlyOwner | Remove a strategy |
| `setActiveStrategy(id, index)` | onlyOwner | Set active strategy |
| `rebalance(id, from, to, amount)` | onlyOwner | Move funds between strategies |

#### Deposit Flow

1. User calls `deposit(id, assets)`
2. Vault calculates shares using `_convertToShares()`
3. Updates `totalAssets[id]` and `totalShares[id]`
4. Mints ERC-6909 tokens to user
5. Transfers assets from user to vault
6. Automatically deposits to active strategy

#### Withdraw Flow

1. User calls `withdraw(id, shares)`
2. Calculates assets to return (includes yield)
3. If idle balance insufficient, withdraws from active strategy
4. Burns user's shares
5. Updates accounting
6. Transfers assets to user

---

### BaseStrategy.sol

**Location**: `src/strategy/Base/BaseStrategy.sol`

**Purpose**: Abstract contract defining the standard interface all strategies must implement.

#### Requirements for Strategies

```solidity
function deposit(uint256 amount) external;      // Must be callable by vault
function withdraw(uint256 amount) external returns (uint256);
function totalAssets() external view returns (uint256);
```

#### Security

- Uses `onlyVault` modifier to restrict sensitive functions
- Immutable `vault` reference set in constructor

---

### AaveStrategyV3.sol

**Location**: `src/strategy/AaveStrategyV3.sol`

**Purpose**: Wraps Aave V3 protocol for yield generation via lending.

#### Constructor Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `_vault` | address | The UnifiedVault contract address |
| `_asset` | address | The underlying asset (e.g., USDC) |
| `_poolProvider` | address | Aave PoolAddressesProvider for network |

#### Key Features

- Supplies assets to Aave V3 pools
- Tracks position via aToken balance
- Auto-approves Aave pool with max allowance

---

### MorphoStrategy.sol

**Location**: `src/strategy/MorphoStrategy.sol`

**Purpose**: Wraps Morpho protocol for yield generation.

#### Constructor Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `_vault` | address | The UnifiedVault contract address |
| `_asset` | address | The underlying asset |
| `_morpho` | address | Morpho protocol contract |
| `_loanToken` | address | Market loan token |
| `_collateralToken` | address | Market collateral token |
| `_oracle` | address | Price oracle |
| `_irm` | address | Interest rate model |
| `_lltv` | address | Loan-to-value curve |

#### Key Features

- Supplies to Morpho markets
- Uses `convertToAssets()` to report total position

---

## Interfaces

### IStrategy.sol

**Location**: `src/interfaces/IStrategy.sol`

Standard interface all strategies must implement:

```solidity
interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external returns (uint256);
    function totalAssets() external view returns (uint256);
}
```

### IMorpho.sol

**Location**: `src/interfaces/IMorpho.sol`

Morpho protocol interface with market configuration struct:

```solidity
struct MarketParams {
    address loanToken;        // Borrowed asset
    address collateralToken;  // Supplied asset
    address oracle;           // Price oracle
    address irm;              // Interest rate model
    address lltv;             // Loan-to-value curve
}
```

### IAavePool.sol & IPoolAddressesProvider.sol

**Locations**: `src/interfaces/IAavePool.sol`, `src/interfaces/IPoolAddressesProvider.sol`

Aave V3 protocol interfaces for pool operations and address lookup.

---

## Security Features

### Virtual Assets/Shares (ERC-4626 Style)

```solidity
uint256 internal constant VIRTUAL_SHARES = 10 ** 18;
uint256 internal constant VIRTUAL_ASSETS = 1;
```

Prevents donation/inflation attacks by adding virtual values to share calculations.

### Access Control

- `onlyOwner`: Functions that modify strategies or assets
- `onlyVault` (in strategies): Only vault can call deposit/withdraw

### Strategy Isolation

- Each strategy is a separate contract
- Bug in one strategy doesn't affect others
- Strategies don't hold shares, only vault does

---

## Development

### Build Commands

```bash
# Install dependencies
forge install

# Compile
forge build

# Run tests
forge test

# Format code
forge fmt
```

### Configuration

**foundry.toml**:
```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
```

### Dependencies

- `forge-std`: Foundry testing utilities
- `openzeppelin-contracts`: ERC-6909, ERC-20, Ownable, SafeERC20, Math

---

## Architecture Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER                                     │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                     UNIFIED VAULT                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ERC-6909: Mints/burns shares (Token ID per asset)      │   │
│  │  Accounting: totalAssets, totalShares per ID            │   │
│  │  Strategy Management: add/remove/set active             │   │
│  └─────────────────────────────────────────────────────────┘   │
└───────────────────┬───────────────────────┬─────────────────────┘
                    │                       │
         ┌──────────▼──────────┐  ┌────────▼─────────┐
         │   AaveStrategyV3    │  │  MorphoStrategy  │
         │  (Aave V3 lending)  │  │  (Morpho market) │
         └──────────┬──────────┘  └────────┬─────────┘
                    │                       │
         ┌──────────▼──────────────────────▼─────────┐
         │         EXTERNAL PROTOCOLS                 │
         │  Aave V3 Pool     │    Morpho             │
         └───────────────────────────────────────────┘

                    ▲
                    │
┌───────────────────┴─────────────────────────────────────────────┐
│                    ALLOCATOR BOT (Off-Chain)                     │
│  - Monitors APYs across protocols                                │
│  - Calls rebalance() to move funds to highest yielding strategy  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Adding a New Strategy

1. Create new contract inheriting `BaseStrategy`
2. Implement `deposit()`, `withdraw()`, `totalAssets()`
3. Deploy with vault address
4. Call `vault.addStrategy(assetId, strategyAddress)`
5. Call `vault.setActiveStrategy(assetId, index)` to make it active

Example structure:

```solidity
import {BaseStrategy} from "./Base/BaseStrategy.sol";

contract MyStrategy is BaseStrategy {
    constructor(address _vault, /* strategy params */) BaseStrategy(_vault) {
        // Setup
    }

    function deposit(uint256 amount) external override onlyVault {
        // Deposit logic
    }

    function withdraw(uint256 amount) external override onlyVault returns (uint256) {
        // Withdraw logic
        return amountWithdrawn;
    }

    function totalAssets() external view override returns (uint256) {
        // Return balance in protocol
    }
}
```

---

## Recent Changes

Based on git history:
- `76b0add` - FIX: strategies errors
- `b9fe6aa` - Add strategies
- `0009ac1` - add README
- `5f133e4` - Core

Current modifications (uncommitted):
- `src/core/UnifiedVault.sol` - Has staged changes

---

## License

MIT
