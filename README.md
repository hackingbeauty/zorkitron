# Zorkitron

A Uniswap v4 Hook Contract for generating DeFi Passive Income yield that contributes to the decentralization of Ethereum. 

![Zorkitron Uniswap v4 Hook Contract](Zorkitron.png "DeFi Passive Income yield generartion Uniswap v4 Hook")

## Concept

![Zorkitron Uniswap v4 Hook](ZorkitronUniswapV4Hook.jpg "Smart Contract Cash Flow Uniswap v4 Hook")

## Links

* Zorkitron Hook Contract address: 0x46363Da87E97d5B30d62Ce7748fE549f48E8c500
    ** https://sepolia.etherscan.io/address/0x46363Da87E97d5B30d62Ce7748fE549f48E8c500

* Zorkitron Router Contract address: 0x25f88C973442B575b13241Cc3627C3552851A0e1
    ** https://sepolia.etherscan.io/address/0x25f88C973442B575b13241Cc3627C3552851A0e1

* Zorkitron Dapp Front-end URL:
    ** https://zorkitron.netlify.app

## Foundry Documentation

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https:book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

# Deploy a Uniswap v4 Hook to a Real Network

https://uniswap.atrium.academy/courses/uniswap-hook-incubator/deploying-a-hook-to-a-real-network/