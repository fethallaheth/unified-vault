# Unified Vault

A modular yield aggregator built on ERC-6909. Users deposit assets; an off-chain allocator optimizes yield across protocols.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         USER                                 │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                     UNIFIED VAULT                            │
│              • Deposit/Withdraw                              │
│              • Share accounting (ERC-6909)                    │
│              • Strategy management                           │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         ▼                       ▼
┌─────────────────┐     ┌─────────────────┐
│  AaveStrategy   │     │  MorphoStrategy │
│  (Aave V3)      │     │  (Morpho)       │
└─────────────────┘     └─────────────────┘
         │                       │
         └───────────┬───────────┘
                     ▼
          ┌──────────────────────┐
          │   Off-Chain Allocator │
          │   (Rebalances funds)  │
          └──────────────────────┘
```

## Installation

```bash
forge install
forge build
forge test
```

## Usage

**Deploy:**
```bash
forge script script/DeployUnifiedVault.s.sol:DeployLocal --rpc-url anvil --broadcast
```

**Deploy Strategy:**
```bash
VAULT_ADDRESS=<vault> ASSET_ADDRESS=<asset> \
forge script script/RegisterStrategy.s.sol:RegisterStrategy --sig "deployAaveStrategy()" \
--rpc-url <RPC> --broadcast
```

## License

MIT
