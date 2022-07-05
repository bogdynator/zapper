# Router contract inspired by Uniswap v2

## Usage

### Pre Requisites

Before running any command, you need to create a `.env` file and set a BIP-39 compatible mnemonic as an environment
variable. Follow the example in `.env.example`. If you don't already have a mnemonic, use this [website](https://iancoleman.io/bip39/) to generate one.

Then, proceed with installing dependencies:

```sh
yarn install
yarn add hardhat
yarn add hardhat-docgen
yarn add @uniswap/lib
yarn add @uniswap/v2-core
yarn add @uniswap/v2-periphery
```

Before running the tests make sure to change the init code from:

```sh
node_modules/@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol at line 24
```

from

```sh
96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f
```

to

```sh
e699c2c70a1e9ca16c58b40782745b5d609738b755845b6ee18a18d21352f753
```

### Compile

Compile the smart contracts with Hardhat:

```sh
$ npx hardhat compile
```

### TypeChain

Compile the smart contracts and generate TypeChain artifacts:

```sh
$ yarn run typechain
```

### Lint Solidity

Lint the Solidity code:

```sh
$ yarn lint:sol
```

### Lint TypeScript

Lint the TypeScript code:

```sh
$ yarn lint:ts
```

### Test

Run the Mocha tests:

```sh
$ npx hardhat test
```

### Coverage

Generate the code coverage report:

```sh
$ yarn add hardhat-coverage
$ npx hardhat coverage --testfiles "./test"
```

### Clean

Delete the smart contract artifacts, the coverage reports and the Hardhat cache:

```sh
$ npx hardhat clean
```

## Syntax Highlighting

If you use VSCode, you can enjoy syntax highlighting for your Solidity code via the [hardhat-vscode](https://github.com/NomicFoundation/hardhat-vscode) extension.

# Contracts

CustomRouterV3 - the scope of this repo

The rest of contracts are made only to simulate the behavior of router in tests

# DISCLAIMER

These contracts are not audited, use at your own risk!
