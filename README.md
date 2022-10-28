
![float capital](/assets/float-saver.gif)

_"Float like a butterfly, reentrancy like a bee"_ - Unknown


# Float contest details 🌊

- 10,700 USDC main award pot 💰💰💰
- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the issue page in your private contest repo (label issues as med or high)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)
- Starts November 2, 2022 15:00 UTC 🚨
- Ends November 5, 2022 15:00 UTC 🚨

# Resources

- [Website](https://float.capital/) (Play around with the alpha deployed last year.)
- [Docs](https://docs.float.capital/docs/) (These docs are for the alpha version, different to this code.)
- [Blog](https://docs.float.capital/blog/)
- [GitHub](https://github.com/Float-Capital)
- [Twitter](https://twitter.com/float_shipping) (Give us a follow, we know you want to)


# Audit scope

The following files are in scope 🚨🚨
```
./contracts/oracles/OracleManagerFixedEpoch.sol
./contracts/YieldManagers/MarketLiquidityManagerSimple.sol
./contracts/market/template/MarketExtended.sol
./contracts/market/template/MarketTieredLeverage.sol
./contracts/PoolToken/PoolTokenMarketUpgradeable.sol
```

## Hello Watsons 👋

Yes! You're here! Awesome. We are super excited for your journey on unpacking and dissecting our code. We will do our best to be available around the clock for all your questions, small, big, silly or severe (catch us on the Sherlock discord).

For a verbose walkthrough of the system be sure to watch the [videos](link coming) that will take you through the system in finer details. 

We wish you luck on your audit.

Happy hunting 🕵

_Float team_


## About Float

Float Arctic is tokenized long/short pools. More info coming soon.

## General

Steps to compile code.

```bash
forge install
forge build
forge test
```

In addition to forge this repo uses hardhat and the javascript ecosystem for some tooling. Please use [pnpm](https://pnpm.io) rather than npm or yarn for a stable experience.

## Commands

build the solidity code with hardhat:

```bash
pnpm compile
```

format the solidity code:

```bash
pnpm format-contracts
```

lint the solidity code:

```bash
pnpm lint-contracts
```

generate metrics about the solidity:

```bash
pnpm generate-metrics
```

save gas usage information from tests to file:

```bash
pnpm generate-gas-metrics
```

Generate document website from natspec in code:

```bash
pnpm dodoc-gen
```

Note - more features and plugins of hardhat can be turned on/off inside the `hardhat.js` file.

## Code Coverage

```bash
forge coverage --report lcov && genhtml lcov.info -o coverage
```

To run that command you'll need [lcov](https://github.com/linux-test-project/lcov) installed. That can be installed via `sudo apt install lcov` or `brew install lcov` etc.

## forge tests (Foundry)

Install cargo + rust `curl https://sh.rustup.rs -sSf | sh`.

Install foundry (+ forge & cast) `curl -L https://foundry.paradigm.xyz | bash` then re-source environment and run `foundryup`.

Compile contracts `forge build`.

Test contracts `forge test`.

## deploying (foundry)

Install foundry and pnpm

Deploy dry run simulated without broadcasting `pnpm deploy-mumbai` or `pnpm deploy-fuji` etc.

To broadast to network add `--broadcast` eg. `pnpm deploy-mumbai --broadcast`

Add any desired forge flags such as `--slow`

## Tools

### Mythril

**Install**

`pip3 install mythril`

(may require `pip3 install maturin` and the latest beta/nightly version of rust to work `rustup toolchain install nightly` and `rustup default nightly`).

**Then run:**

```bash
myth analyze ./contracts/market/MarketTieredLeverage.sol --solc-json ./scripts/mythril.json
```

(or for docker install `docker run -v$(pwd):/tmp -w="/tmp" mythril/myth analyze ./contracts/market/MarketTieredLeverage.sol --solc-json ./scripts/mythril.json`)

### Slither

**Install**

`pip3 install slither-analyzer`

**Run:**

`slither .`

_NOTE:_ You can run slither faster if it uses the compilation output from forge directly. Do this by running `forge build --extra-output abi --extra-output userdoc --extra-output devdoc --extra-output evm.methodIdentifiers` and then running `slither . --ignore-compile`.

**Using Docker**

You can run the same commands as above but inside docker.

`docker run -it -v $(pwd):/share trailofbits/eth-security-toolbox`

Then inside run `solc-select 0.8.15` and run slither (and some of the other tools potentially) from within there. Note, `forge` isn't installed in that docker image, so you'll need to build outside and run slither with the `--ignore-compile` flag.

**Viewing and reviewing results**

One nice way to view the results from slither (much nicer than in the terminal) is to generate a `--sarif result.sarif` flag. You can then install a vscode (or equivalent) plugin to interpret that file to easily navigate the output and findings.

Since slither won't over-write your results it is often useful to use `--sarif results_$(date +"%m-%d-%Y_%T").sarif` which will append the time and date to the results for easy reference.

It is also can be useful to run a `--triage` and fix the issues one at a time.

## Troubleshooting

Often the forge compiler is over eager on its caching (which is good - makes things fast), but it can also cause issues! Before you spend hours debugging something mysterious in the contracts make sure to clear the cache. Do this via `forge cache clean` and/or deleting the cache `rm -rf ./cache` and/or running the contracts with the `--force`/`-f` flag to force them to re-compile completely.
