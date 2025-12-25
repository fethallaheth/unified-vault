# Unified Vault

[![Solidity](https://img.shields.io/badge/Solidity-0.8.19-blue.svg)](https://soliditylang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Unified Vault** is a modular, off-chain managed yield aggregator built on the **ERC-6909** multi-token standard. It allows users to deposit assets into a single vault while automatically optimizing yield across multiple DeFi protocols (Aave, Morpho, Lido, etc.) via an off-chain "Allocator" bot.

---

## 🌟 Overview

Traditional yield aggregators often hardcode strategies or rely on complex on-chain logic to rebalance funds, leading to high gas fees and rigidity. **Unified Vault** solves this by separating the **Accounting Layer** (The Vault) from the **Execution Layer** (The Strategies).

Users simply deposit an asset (e.g., USDC) and receive **Token ID #1**. In the background, an off-chain manager actively shifts these funds between the highest-yielding protocols, maximizing returns without the user ever needing to understand complex DeFi mechanics.

## 🏗️ Architecture

The protocol consists of three distinct layers:

1.  **The Vault (ERC-6909):** A single immutable contract that handles user deposits, accounting, and share issuance.
2.  **The Strategies:** Modular, non-tokenized contracts that wrap specific DeFi protocols (e.g., Aave, Morpho).
3.  **The Allocator (Off-Chain):** A sophisticated bot that monitors APYs across chains and executes `rebalance` transactions to move funds to the best opportunities.

### Visual Flow

```text
[ USER ] 
   | 1. Deposit USDC
   v
[ UNIFIED VAULT ]  <---> [ ALLOCATOR BOT (Off-Chain) ]
   |                     |
   | 2. Mint Token ID #1 | 3. Monitors APYs (Aave vs Morpho)
   |                     | 4. Calls rebalance(to=Morpho)
   v                     v
[ ASSETS ] ----------> [ MORPHO STRATEGY ]
   ^
   | 5. Funds flow back to user on withdraw
```

---

## 🧩 Core Components

### Unified Vault
The central contract inheriting from **ERC-6909**.
*   **Role:** Acts as the bank and accountant.
*   **Function:** Mints/burns shares and routes funds to strategies.
*   **Key Function:** `rebalance(address _from, address _to, uint256 _amount)` — allows the allocator to shift positions.

### Strategies
Tiny, gas-efficient wrapper contracts for specific protocols.
*   **Role:** The adapters.
*   **Function:** They know how to `deposit` and `withdraw` from a single external protocol (e.g., `AaveStrategy`, `MorphoStrategy`).
*   **Benefit:** Isolates risk. A bug in the Morpho strategy does not affect the Aave strategy or the main Vault.

### The Allocator
An off-chain script (Node.js/Python) running on a secure server.
*   **Role:** The active fund manager.
*   **Function:** Fetches APY data from oracles (e.g., The Graph, DefiLlama) and signs transactions to optimize the portfolio.

---


## 🚀 Getting Started

### Prerequisites
- Node.js >= 16
- Yarn or NPM
- Git

### Installation

1.  **Clone the repo**
    ```bash
    git clone https://github.com/fethallaheth/unified-vault.git
    cd unified-vault
    ```

2.  **Install dependencies**
    ```bash
    forge install
    ```

3.  **Compile contracts**
    ```bash
    forge compile
    ```

4.  **Run tests**
    ```bash
    forge test
    ```

---


## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
