# Collateralized Debt Position Stable Coin

## About

This project is a CDP stable coin project. The properties of the stable coin are as follows:

- Relative Stability: pegged to $1.00 US
- Stability Mechanism (Minting): Algorithmic (Decentralised)
- Collateral Type Supported: Exogenous
  - wBTC
  - wETH

Chainlink Pricefeeds will be used to retrieve the price of collateral assets and determine whether positions are able to be liquidated.

## Table of contents

1. [Getting started](#getting-started)
   - [1.1 Requirements](#requirements)
   - [1.2 Quickstart](#quickstart)
2. [Usage](#usage)
   - [2.1 Deploying Locally](#deploying-locally)
   - [2.2 Deploying to a testnet or mainnet](#deploying-to-a-testnet-or-mainnet)
3. [Testing](#testing)
   - [3.1 Unit tests](#unit-tests)
   - [3.2 Coverage](#test-coverage)
4. [Additional Notes](#additional-notes)
5. [Acknowledgements](#acknowledgements)

## Getting Started

### Requirements

The following must be installed on your machine:

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git/)
- [foundry](https://book.getfoundry.sh/getting-started/installation)

### Quickstart:

```
git clone https://github.com/MGM103/CDP_Stable_Coin.git
cd CDP_Stable_Coin
make build
```

## Usage

### Deploying locally

In one terminal run anvil. Anvil is a local Ethereum node, designed for development with Forge, akin to Ganache.

```
anvil
```

In another terminal run the following command to deploy:

```
make deploy
```

### Deploying to a testnet or mainnet

1. **Setup environment variables**

You'll want to set your `SEPOLIA_RPC_URL`, `PRIVATE_KEY` as environment variables. You can add them to a `.env` file.

- `PRIVATE_KEY`: The private key of your account (like from [metamask](https://metamask.io/)). **NOTE:** FOR DEVELOPMENT, PLEASE USE A KEY THAT DOESN'T HAVE ANY REAL FUNDS ASSOCIATED WITH IT.
  - You can [learn how to export it here](https://metamask.zendesk.com/hc/en-us/articles/360015289632-How-to-Export-an-Account-Private-Key).
- `SEPOLIA_RPC_URL`: This is url of the sepolia testnet node you're working with. You can get setup with one for free from [Alchemy](https://alchemy.com/?a=673c802981)
- `ETHERSCAN_API_KEY` to verify your contract on [Etherscan](https://etherscan.io/).

2. **Get testnet ETH**

Head over to [faucets.chain.link](https://faucets.chain.link/) and get some testnet ETH. You should see the ETH show up in your metamask.

3. **Deploy**

```
make deploy ARGS="--network sepolia"
```

4. **Verify you contract**

```
make verify
```

## Testing

### Unit tests

To run the unit tests for this project you can run the following commands:

```
forge test // run all tests
forge test --mt <testFunctionName> // run specific test
```

### Test Coverage

To see the amount of coverage the tests in the project cover of the codebase you can run the following command:

```
forge coverage
```

## Additional Notes

If you are unfamiliar with the foundry smart contract development framework please refer to: https://book.getfoundry.sh/

## Acknowledgements

Full credit must go to [Patrick Collins](https://github.com/PatrickAlphaC). He is a fantastic teacher of blockchain development and this project came from his [course](https://github.com/Cyfrin/foundry-full-course-f23). If you are interested in learning more please checkout his [youtube](https://www.youtube.com/@PatrickAlphaC).
