# Zorkitron - Uniswap v4 Rehypothecation Hook

Zorkitron is a Uniswap v4 hook contract that enables Liquidity Providers to deposit assets into external ERC-4626 yield vaults when not being used while also providing Just-In-Time (JIT) liquidity to pools during swaps.

This mechanism enables idle assets to generate yield while also providing liquidity for trading but only when needed for a swap.  Liquidity is removed from a pool right after a swap and is then actively invested in novel new yield generating vaults.

Key features include:

* __Yield Generation and JIT Liquidity__: The contract deposits assets into yield-generating vaults, then uses those same assets to provide either full-range or custom-range JIT liquidity during the `beforeSwap` lifecyle hook, and then removes the assets from the pool in the `afterSwap` lifecyle hook. 

* __Slippage Protection__: Configures slippage bounds for liquidity operations in order to prevent sandwich attacks.  The functions {addRehypothecatedLiquidity} and {removeRehypothecatedLiquidity} now require `amount0Max/amount1Max` and `amount0Min/amount1Min` parameters, reverting with `TooMuchSlippage` if bounds are exceeded.

* __Security Hardening__: The contract addresses critical vulnerabilities such as **swaps with no usable JIT liquidity** (reverting if the contract cannot back a swap) and **liquidity overflow** (capping JIT liquidity size at at the per-tick limit to prevent `TickLiquidityOverflow` errors);

* __Atomic Withdrawals__: Prevents reentrancy or accounting issues when the pool state changes before all assets are transferred.The contract withdraws both currencies from yield sources before paying out withdrawals.

* __Fee-Free Yield Sources__: The contract assumes yield sources (i.e. vaults) are fee-free; deposit or withdrawal fees in yield sources can skew share-to-amount conversions harming other Liquidity Providers.

The contract relies on Uniswap v4's core hook functions using `beforeInitialize`, `beforeSwap`, and `afterSwap` callbacks to manage the lifecycle of rehypothecated positions.

_
### Get Started
_
This template provides a starting point for writing Uniswap v4 Hooks, including a simple example and preconfigured test environment. Start by creating a new repository using the "Use this template" button at the top right of this page. Alternatively you can also click this link:

[![Use this Template](https://img.shields.io/badge/Use%20this%20Template-101010?style=for-the-badge&logo=github)](https://github.com/uniswapfoundation/v4-template/generate)

1. The example hook [Counter.sol](src/Counter.sol) demonstrates the `beforeSwap()` and `afterSwap()` hooks
2. The test template [Counter.t.sol](test/Counter.t.sol) preconfigures the v4 pool manager, test tokens, and test liquidity.

<details>
<summary>Updating to v4-template:latest</summary>

This template is actively maintained -- you can update the v4 dependencies, scripts, and helpers:

```bash
git remote add template https://github.com/uniswapfoundation/v4-template
git fetch template
git merge template/main <BRANCH> --allow-unrelated-histories
```

</details>

### Requirements

This template is designed to work with Foundry (stable). If you are using Foundry Nightly, you may encounter compatibility issues. You can update your Foundry installation to the latest stable version by running:

```
foundryup
```

To set up the project, run the following commands in your terminal to install dependencies and run the tests:

```
forge install
forge test
```

### Local Development

Other than writing unit tests (recommended!), you can only deploy & test hooks on [anvil](https://book.getfoundry.sh/anvil/) locally. Scripts are available in the `script/` directory, which can be used to deploy hooks, create pools, provide liquidity and swap tokens. The scripts support both local `anvil` environment as well as running them directly on a production network.

### Executing locally with using **Anvil**:

1. Start Anvil (or fork a specific chain using anvil):

```bash
anvil
```

or

```bash
anvil --fork-url <YOUR_RPC_URL>
```

2. Execute scripts:

```bash
forge script script/00_DeployHook.s.sol \
    --rpc-url http://localhost:8545 \
    --private-key <PRIVATE_KEY> \
    --broadcast
```

### Using **RPC URLs** (actual transactions):

:::info
It is best to not store your private key even in .env or enter it directly in the command line. Instead use the `--account` flag to select your private key from your keystore.
:::

### Follow these steps if you have not stored your private key in the keystore:

<details>

1. Add your private key to the keystore:

```bash
cast wallet import <SET_A_NAME_FOR_KEY> --interactive
```

2. You will prompted to enter your private key and set a password, fill and press enter:

```
Enter private key: <YOUR_PRIVATE_KEY>
Enter keystore password: <SET_NEW_PASSWORD>
```

You should see this:

```
`<YOUR_WALLET_PRIVATE_KEY_NAME>` keystore was saved successfully. Address: <YOUR_WALLET_ADDRESS>
```

::: warning
Use `history -c` to clear your command history.
:::

</details>

1. Execute scripts:

```bash
forge script script/00_DeployHook.s.sol \
    --rpc-url <YOUR_RPC_URL> \
    --account <YOUR_WALLET_PRIVATE_KEY_NAME> \
    --sender <YOUR_WALLET_ADDRESS> \
    --broadcast
```

You will prompted to enter your wallet password, fill and press enter:

```
Enter keystore password: <YOUR_PASSWORD>
```

### Key Modifications to note:

1. Update the `token0` and `token1` addresses in the `BaseScript.sol` file to match the tokens you want to use in the network of your choice for sepolia and mainnet deployments.
2. Update the `token0Amount` and `token1Amount` in the `CreatePoolAndAddLiquidity.s.sol` file to match the amount of tokens you want to provide liquidity with.
3. Update the `token0Amount` and `token1Amount` in the `AddLiquidity.s.sol` file to match the amount of tokens you want to provide liquidity with.
4. Update the `amountIn` and `amountOutMin` in the `Swap.s.sol` file to match the amount of tokens you want to swap.

### Verifying the hook contract

```bash
forge verify-contract \
  --rpc-url <URL> \
  --chain <CHAIN_NAME_OR_ID> \
  # Generally etherscan
  --verifier <Verification_Provider> \
  # Use --etherscan-api-key <ETHERSCAN_API_KEY> if you are using etherscan
  --verifier-api-key <Verification_Provider_API_KEY> \
  --constructor-args <ABI_ENCODED_ARGS> \
  --num-of-optimizations <OPTIMIZER_RUNS> \
  <Contract_Address> \
  <path/to/Contract.sol:ContractName>
  --watch
```

### Troubleshooting

<details>

#### Permission Denied

When installing dependencies with `forge install`, Github may throw a `Permission Denied` error

Typically caused by missing Github SSH keys, and can be resolved by following the steps [here](https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh)

Or [adding the keys to your ssh-agent](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#adding-your-ssh-key-to-the-ssh-agent), if you have already uploaded SSH keys

#### Anvil fork test failures

Some versions of Foundry may limit contract code size to ~25kb, which could prevent local tests to fail. You can resolve this by setting the `code-size-limit` flag

```
anvil --code-size-limit 40000
```

#### Hook deployment failures

Hook deployment failures are caused by incorrect flags or incorrect salt mining

1. Verify the flags are in agreement:
   - `getHookCalls()` returns the correct flags
   - `flags` provided to `HookMiner.find(...)`
2. Verify salt mining is correct:
   - In **forge test**: the _deployer_ for: `new Hook{salt: salt}(...)` and `HookMiner.find(deployer, ...)` are the same. This will be `address(this)`. If using `vm.prank`, the deployer will be the pranking address
   - In **forge script**: the deployer must be the CREATE2 Proxy: `0x4e59b44847b379578588920cA78FbF26c0B4956C`
     - If anvil does not have the CREATE2 deployer, your foundry may be out of date. You can update it with `foundryup`

</details>

### Additional Resources

- [Uniswap v4 docs](https://docs.uniswap.org/contracts/v4/overview)
- [v4-periphery](https://github.com/uniswap/v4-periphery)
- [v4-core](https://github.com/uniswap/v4-core)
- [v4-by-example](https://v4-by-example.org)


### Revert v4lend

https://github.com/revert-finance/v4lend

### AI-Assisted Formal Verification (Certora Links)

https://www.certora.com/blog/best-practices-for-writing-secure-uniswap-v4-hooks

https://predictablemachines.com/


### ChatGPT Response

Write me a Uniswap v4 hook contract the deposits a user's Uniswap v4 NFT position as collateral on Revert Lend in exchange for DAI ERC-20 tokens.

Yes—but there is an important protocol-compatibility issue to resolve first.

Revert Lend currently documents collateralization of Uniswap v3 LP NFTs, not Uniswap v4 PositionManager NFTs. Uniswap v4 positions are ERC-721s issued by the v4 PositionManager, with position state maintained through the v4 PoolManager.

Also, a v4 hook is not the right component by itself for this operation. Hooks execute at specific points in a v4 pool's lifecycle; depositing an NFT into a lending protocol and borrowing DAI is an external position-management operation.

So I would structure the system as:

User
 │
 │  deposit v4 PositionManager NFT
 ▼
Collateral Adapter
 │
 ├── verifies NFT ownership
 ├── transfers/escrows v4 NFT
 ├── determines position value
 ├── supplies collateral to lending layer
 └── borrows DAI
 │
 ▼
Revert-compatible Lending Vault
 │
 └── DAI ───────────────► User

The critical part is that Revert Lend would need a vault/adapter capable of accepting the v4 NFT. You cannot simply call the existing Revert v3 collateral function with a v4 tokenId.

If you're building this as a new protocol integration, I can write the Solidity implementation with:

UniswapV4CollateralHook
RevertV4CollateralAdapter
ERC-721 custody of the v4 PositionManager NFT
DAI borrowing
LTV / liquidation thresholds
repayment and NFT withdrawal
authorization so only the NFT owner can borrow
protection against depositing someone else's NFT
position valuation using the v4 pool state
liquidation logic
Foundry tests

### Collateral Debt Positions (CDP)

// Definitions:
// Collateral Debt Position - A collateral debt position (CDP) is a financial arrangement where a user 
// locks up collateral, typically in the form of cryptocurrency, to borrow or mint stablecoins. This system 
// is commonly used in decentralized finance (DeFi) platforms, allowing users to access loans without 
// traditional banking processes.

### Lido (Liquid Staking Protocol) Docs

https://docs.lido.fi/