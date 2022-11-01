
![float capital](/assets/float-saver.gif)

_"Float like a butterfly, uint256 like a bee"_ - Unknown


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
./contracts/oracles/OracleManager.sol
./contracts/YieldManagers/MarketLiquidityManagerSimple.sol
./contracts/market/template/MarketExtended.sol
./contracts/market/template/MarketCore.sol
./contracts/PoolToken/PoolToken.sol
```

## Hello Watsons 👋

Yes! You're here! Awesome. We are super excited for your journey on unpacking and dissecting our code. We will do our best to be available around the clock for all your questions, small, big, silly or severe (catch us on the Sherlock discord).

For a walkthrough of the system be sure to watch the [videos](link coming) that will take you through the system in finer details. 

We wish you luck on your audit.

Happy hunting 🕵

_Float team_


---------------------------------------

## Float deepdive

### About float

Float Arctic is infrastructure to create tokenized pools (long/short/float) where pool token value tracks a data feed (price feed, exotic etc). Tokenized pools have collateral (ERC20 token) backing them. Pool token value increases/decreases as collateral moves between pools (zero-sum game). 

Collateral moves between pools because of:
1 - New point in data feed (e.g. ETH price up)
2 - Funding
3 - Fees 

Collateral enters/exits pools because of:
1 - Users minting new pool tokens (adding collateral)
2 - Users burning pool tokens (removing collateral)



Multiple long and short pools can exist in a market. Each pool can have a different leverage. 



### Tranching

Tranches are portions of financial products structured to divide risk or group characteristics in ways that are marketable to different users. In traditional finance for example, a product like debt would be separated into junior and senior tranches with different risk/return characteristics. 

![float capital](/assets/system1.png)

In float, the FLOAT tranche is essentailly:
1 - The counterparty (will be long or short or neutral, wherever needed)
2 - Wil have its delta (long/short exposure) frequently shift to ensure on aggregate long = short. 
3 - Recieve funding + stablility fees from all other long/short pools (i.e. the fixed exposure tranches)


![float capital](/assets/system2.png)


In the intuative diagram below you should be able to follow how value transfers between pools and how the leverage of the FLOAT pool adjusts to ensure on aggregate the liquidity is equal in long and short. You can view this scenario in more detail [here](https://app.excalidraw.com/l/2big5WYTyfh/AsMLUl3D5WY).
![float capital](/assets/system3.png)




### Understanding epochs

The process of value transfer / entrants and exits all get processed in a predictable way using a system of "epochs".
Every epoch, we need to perform upkeep. Upkeep is essentially:
- Processing value transfer between pools based on movement of data feed and funding + fees.
- Processing new entries and exits to all pools.

The diagram below shows that mints/redeems occuring in epoch 1, will be processed and executed when a price is received after a given wait period. This ensures defense against front running while allowing a batch effcient method to execute multiple actions at a single point.

![epochs](/assets/epoch.png)







### The contracts

```
./contracts/market/template/MarketCore.sol
```

This contract contains all the core logic related to the market. Minting and redeeming, the value transfer between pools, calculating funding etc. This is the most important contract. 

Since a single contract was too large for deployment, we split the market contract into 2 parts. MarketCore is the core logic of the system - but MarketCore doubles as a proxy (via an EIP-1967 proxy) and all the functions for initialization or other seldom used admin functionality like adding new pools resides in that contract. This gives us the flexibility of still using a UUPS upgrade pattern without increasing gas costs of the common/core contract functions. 

```
./contracts/market/template/MarketExtended.sol

```
This contract contains non-core market functions that are rarely used (intially setting up the pools, parameter configuartion etc) and thus have lower gas costs.

| ![contract structure](/assets/market-contract-structure.png) | 
|:--:| 
| *Structure of the Market Contracts* |

```
./contracts/oracles/OracleManager.sol
```
This contract validates that the oracle id's passed in for execution/upkeep are valid then eturns the prices to use to execute the value change. Any possibilty to maniuplate this contract or bypass its check could result in an errenous value transfer. 


```
./contracts/YieldManagers/MarketLiquidityManagerSimple.sol

```
This is a very simple contract this just holds all the collateral. Previously in the alpha this contract deposited liquidity into a yield protocol (aave) but we have removed this functionality now. 


```
./contracts/PoolToken/PoolToken.sol
```
Modified ERC20 token contract. Think tokenized vault. 

---------------------------------------
## Considerations

- The public function for upkeep takes in oracle IDs to use for updating the system? 

This is designed this way to keep system updates cheaper on gas. All the computation for determining oracle IDs is on chain in the form of a keeper (gelato & chainlink keepers) - so in the case of emergancy those more costly functions can be called from the keeper.

- Oracle failure (no price updates recieved in an epoch)

This will activate a market deprecation counter. Users won't be able to enter/exit the market while this issue is being investigated for safety. Once cause of issue has been identified, resolutions can be made in the form of a smart contract upgrade to relevant parts of our system, manually deprecating the market - or waiting for the auto market deprecation to kick in 10 days after the incident. Once a market is deprecated users will be able to withdraw their funds at the last known price before the oracle failure.

- Black swan price movements bankrupting pools

In the case of having pools tiers with higher leverage it is possible for price movements to bankrupt that tier. For example - in a 10x leverage market - a price movement of 10% or more would against a side would bankrupt that side. To prevent this issue we'd have a maximum price movement of 9%. In the code this variable is called `maxPercentChange`.

- We don’t use `safeTransfer` or check return values of the ‘PoolToken’ transfers since we control that token. Additionally we will only use DAI or maybe USDC as a payment token. Any further payment token will be analysed deeply before use (payment tokens with transfer fees etc will be problematic to the system - we are aware of this).

- What if not enough liquidity exists in float tranche? 

The float tranche will never be exposed to more leverage (possitive or negative) than its maximum which is currently hardcoded at -5x to 5x. After this point, the leverage of the fixed exposure pools will be sacraficed to keep the system working. The market side (long/short) that has an overbalanced effective liquidity will have a lower leverage than when there Float tranche has enough liquidity - but the underbalanced side will have perfect fixed exposure.

- You have loops in your solidity code?

The loops we have in the code are all fixed length which is based on the number of pool tiers in a market. We will keep these loops small and not launch more tiers than feasible.

### Other notes and thoughts 💭

- Admin: We have direct access to setting the fundingRateMultiplier_e18 variable without timelock etc. The solution to that is to make the admin rather be the another contract that manages access and applies restrictions such as timelocks and keep that complexity out of the core logic contracts.

- All our contracts are upgradeable and make heavy use of immutable variables. We are aware that this is a risk and will ensure that we have lots of tests and an upgrade function that checks them to make sure that these values are set correctly on new upgrades. Additionally upgrades will be protected by the timelock mentioned above where the proposer+executor is a multisig contract.

### Structure/standands

- Contract test code is written with the `.t.sol` suffix, and in general is integrated inside the file structure.
- Deployment and manegement scripts use `.s.sol`
- Interface contracts are prefixed with `I`

### Invariants:

- `poolValue` can only change in a system update (single external function).
- `marketDeprecated` ⇒ `mintingPaused`
- UserAction:
  - `userAction.amount` == 0 ⇔ `userAction.correspondingEpoch` == 0
  - `userAction.amount > 0` <IFF> `userAction.correspondingEpoch <= currentEpoch`
  - `userAction.nextEpochAmount > 0` <IFF> `userAction.amount > 0`
- Due to decimal rounding issues, it is possible for the total value deposited in the system to be larger than the sum of the value of all the pools. We believe that the rate of rounding error is tolerable for the system.
![poolSum](/assets/sum-of-value.png)
---------------------------------------
## Get started

Steps to compile code (skip to step 3 if you've used foundry before):

1) Install cargo + rust `curl https://sh.rustup.rs -sSf | sh`.
2) Install foundry (+ forge & cast) `curl -L https://foundry.paradigm.xyz | bash` then re-source environment and run `foundryup`.

3) Install `forge install`
4) Compile contracts `forge build`.
5) Test contracts `forge test`.

TL;DR:
```bash
forge install
forge build
forge test
```

In addition to forge this repo uses hardhat and the javascript ecosystem for some tooling. Please use [pnpm](https://pnpm.io) rather than npm or yarn for a stable experience.

### Other Commands

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

### Code Coverage

```bash
forge coverage --report lcov && genhtml lcov.info -o coverage
```

To run that command you'll need [lcov](https://github.com/linux-test-project/lcov) installed. That can be installed via `sudo apt install lcov` or `brew install lcov` etc.




### Troubleshooting

Often the forge compiler is over eager on its caching (which is good - makes things fast), but it can also cause issues! Before you spend hours debugging something mysterious in the contracts make sure to clear the cache. Do this via `forge cache clean` and/or deleting the cache `rm -rf ./cache` and/or running the contracts with the `--force`/`-f` flag to force them to re-compile completely.


---------------------------------------
## Glossary
#### A

actualValueChange - The actual amount (of payment token / collateral) that should change (increase or decrease). 

#### E

epochIndex - Refers to a specific epoch in the system. Epochs are increase monotonically with 0 being the first epoch index. 

effectiveLiquidity - the liquidity in the market taking into account leverage. I.e. A 2x pool with $50 would have $100 of effective liquidity.
valueChange - The liquidity that needs to flow between the long and short sides. 

effectiveValueLong - Refers to the sum of all long liquidity (taking into account the leverage of each long pool and likely also taking into account float pool liquidity.)
efffectiveValueShort - same as effectiveValueLong but for short. 

#### F

fundingRateMultiplier - A rate used to scale funding amount. 

fundingAmount - the amount of funding that will be received by the generally the FLOAT pool while paid by proportionally (based on their effective liquidity) by the overbalanced pools.

floatPoolLiquidity - the amount of collateral in the FLOAT poolType. 

floatPoolLeverage - the leverage (positive or negative) of the float pool. Float pool leverage adjusts every epoch to balance the markets.

#### G

gems - Purely non-transferable ERC20 tokens collected by users on actions (allowing minting of NFTs etc). 

#### L

latestExecutedEpochIndex - represents the latest epoch where all orders have been executed. 

LiquidityManager - Smart contract that holds all collateral. 

#### M

maxPercentChange - refers to the max percentage price change that can occur between any 2 epochs. Used as a safeguard to ensure that higher leveraged pools never go underwater and create bad debt. 

MINIMUM_EXECUTION_WAIT_THRESHOLD - the time directly after an epoch has finished that needs to elapse before a chainlink price received is deemed to be valid to execute that previous epoch. This is important to prevent front-running as it takes into account time/ latency for prices to be aggregated and transmitted by chainlink. 


#### O

overbalancedValue - Generally refers to the side of the market (long/short) with more liquidity than the other side of the market (underbalanced value)

#### P

paymentToken - This generally refers to the ERC20 token that is used as collateral in the system, which is most cases is DAI. A user will need payment token to mint a position, and a user will receieve payment token when redeeming a position. 

pool - A tokenized vault of collateral where ones share of the collateral is equal to their percentage ownership of the token supply. 

poolType - Typically long or short or float, the type of pool generally dictates how the pool will behave when price movements occur. 

poolTier - refers to one of the many possible pools in a poolType, each poolTier most likely has a certain leverage associated with it. The float poolType will only have a single tier. 

priceMovement - refers to the percentage price movement of the reference asset between any two epochs. In base 1e18. 

#### R

registry - Core contract / factory that can keep track of all deployed smart contract markets and token. 

#### U

underbalancedValue - Generally refers to the side of the market (long/short) with less liquidity than the other side of the market (overbalanced value)

