
[<img width="200" alt="get in touch with Consensys Diligence" src="https://user-images.githubusercontent.com/2865694/56826101-91dcf380-685b-11e9-937c-af49c2510aa0.png">](https://diligence.consensys.net)<br/>
<sup>
[[  🌐  ](https://diligence.consensys.net)  [  📩  ](mailto:diligence@consensys.net)  [  🔥  ](https://consensys.github.io/diligence/)]
</sup><br/><br/>



# Solidity Metrics for Float Arctic Contracts

## Table of contents

- [Scope](#t-scope)
    - [Source Units in Scope](#t-source-Units-in-Scope)
    - [Out of Scope](#t-out-of-scope)
        - [Excluded Source Units](#t-out-of-scope-excluded-source-units)
        - [Duplicate Source Units](#t-out-of-scope-duplicate-source-units)
        - [Doppelganger Contracts](#t-out-of-scope-doppelganger-contracts)
- [Report Overview](#t-report)
    - [Risk Summary](#t-risk)
    - [Source Lines](#t-source-lines)
    - [Inline Documentation](#t-inline-documentation)
    - [Components](#t-components)
    - [Exposed Functions](#t-exposed-functions)
    - [StateVariables](#t-statevariables)
    - [Capabilities](#t-capabilities)
    - [Dependencies](#t-package-imports)
    - [Totals](#t-totals)

## <span id=t-scope>Scope</span>

This section lists files that are in scope for the metrics report. 

- **Project:** `Float Arctic Contracts`
- **Included Files:** 
    - ``
- **Excluded Paths:** 
    - ``
- **File Limit:** `undefined`
    - **Exclude File list Limit:** `undefined`

- **Workspace Repository:** `unknown` (`undefined`@`undefined`)

### <span id=t-source-Units-in-Scope>Source Units in Scope</span>

Source Units Analyzed: **`5`**<br>
Source Units in Scope: **`5`** (**100%**)

| Type | File   | Logic Contracts | Interfaces | Lines | nLines | nSLOC | Comment Lines | Complex. Score | Capabilities |
|========|=================|============|=======|=======|===============|==============|  
| 📝 | ./contracts/oracles/OracleManager.sol | 1 | **** | 137 | 133 | 51 | 55 | 46 | **** |
| 📝 | ./contracts/YieldManagers/MarketLiquidityManagerSimple.sol | 1 | **** | 61 | 61 | 24 | 23 | 24 | **** |
| 📝 | ./contracts/market/template/MarketExtended.sol | 1 | **** | 191 | 181 | 87 | 55 | 99 | **** |
| 📝 | ./contracts/market/template/MarketCore.sol | 1 | **** | 695 | 649 | 326 | 208 | 289 | **<abbr title='Initiates ETH Value Transfer'>📤</abbr>** |
| 📝 | ./contracts/PoolToken/PoolToken.sol | 1 | **** | 153 | 140 | 58 | 63 | 63 | **<abbr title='Initiates ETH Value Transfer'>📤</abbr><abbr title='Uses Hash-Functions'>🧮</abbr>** |
| 📝 | **Totals** | **5** | **** | **1237**  | **1164** | **546** | **404** | **521** | **<abbr title='Initiates ETH Value Transfer'>📤</abbr><abbr title='Uses Hash-Functions'>🧮</abbr>** |

<sub>
Legend: <a onclick="toggleVisibility('table-legend', this)">[➕]</a>
<div id="table-legend" style="display:none">

<ul>
<li> <b>Lines</b>: total lines of the source unit </li>
<li> <b>nLines</b>: normalized lines of the source unit (e.g. normalizes functions spanning multiple lines) </li>
<li> <b>nSLOC</b>: normalized source lines of code (only source-code lines; no comments, no blank lines) </li>
<li> <b>Comment Lines</b>: lines containing single or block comments </li>
<li> <b>Complexity Score</b>: a custom complexity score derived from code statements that are known to introduce code complexity (branches, loops, calls, external interfaces, ...) </li>
</ul>

</div>
</sub>


#### <span id=t-out-of-scope>Out of Scope</span>

##### <span id=t-out-of-scope-excluded-source-units>Excluded Source Units</span>

Source Units Excluded: **`0`**

<a onclick="toggleVisibility('excluded-files', this)">[➕]</a>
<div id="excluded-files" style="display:none">
| File   |
|========|
| None |

</div>


##### <span id=t-out-of-scope-duplicate-source-units>Duplicate Source Units</span>

Duplicate Source Units Excluded: **`0`** 

<a onclick="toggleVisibility('duplicate-files', this)">[➕]</a>
<div id="duplicate-files" style="display:none">
| File   |
|========|
| None |

</div>

##### <span id=t-out-of-scope-doppelganger-contracts>Doppelganger Contracts</span>

Doppelganger Contracts: **`0`** 

<a onclick="toggleVisibility('doppelganger-contracts', this)">[➕]</a>
<div id="doppelganger-contracts" style="display:none">
| File   | Contract | Doppelganger | 
|========|==========|==============|


</div>


## <span id=t-report>Report</span>

### Overview

The analysis finished with **`0`** errors and **`0`** duplicate files.





#### <span id=t-risk>Risk</span>

<div class="wrapper" style="max-width: 512px; margin: auto">
			<canvas id="chart-risk-summary"></canvas>
</div>

#### <span id=t-source-lines>Source Lines (sloc vs. nsloc)</span>

<div class="wrapper" style="max-width: 512px; margin: auto">
    <canvas id="chart-nsloc-total"></canvas>
</div>

#### <span id=t-inline-documentation>Inline Documentation</span>

- **Comment-to-Source Ratio:** On average there are`1.53` code lines per comment (lower=better).
- **ToDo's:** `0` 

#### <span id=t-components>Components</span>

| 📝Contracts   | 📚Libraries | 🔍Interfaces | 🎨Abstract |
|=============|===========|============|============|
| 5 | 0  | 0  | 0 |

#### <span id=t-exposed-functions>Exposed Functions</span>

This section lists functions that are explicitly declared public or payable. Please note that getter methods for public stateVars are not included.  

| 🌐Public   | 💰Payable |
|============|===========|
| 33 | 0  | 

| External   | Internal | Private | Pure | View |
|============|==========|=========|======|======|
| 24 | 57  | 0 | 0 | 9 |

#### <span id=t-statevariables>StateVariables</span>

| Total      | 🌐Public  |
|============|===========|
| 13  | 12 |

#### <span id=t-capabilities>Capabilities</span>

| Solidity Versions observed | 🧪 Experimental Features | 💰 Can Receive Funds | 🖥 Uses Assembly | 💣 Has Destroyable Contracts | 
|============|===========|===========|===========|
| `^0.8.15` |  | **** | **** | **** | 

| 📤 Transfers ETH | ⚡ Low-Level Calls | 👥 DelegateCall | 🧮 Uses Hash Functions | 🔖 ECRecover | 🌀 New/Create/Create2 |
|============|===========|===========|===========|===========|
| `yes` | **** | **** | `yes` | **** | **** | 

| ♻️ TryCatch | Σ Unchecked |
|============|===========|
| **** | **** |

#### <span id=t-package-imports>Dependencies / External Imports</span>

| Dependency / Import Path | Count  | 
|==========================|========|


#### <span id=t-totals>Totals</span>

##### Summary

<div class="wrapper" style="max-width: 90%; margin: auto">
    <canvas id="chart-num-bar"></canvas>
</div>

##### AST Node Statistics

###### Function Calls

<div class="wrapper" style="max-width: 90%; margin: auto">
    <canvas id="chart-num-bar-ast-funccalls"></canvas>
</div>

###### Assembly Calls

<div class="wrapper" style="max-width: 90%; margin: auto">
    <canvas id="chart-num-bar-ast-asmcalls"></canvas>
</div>

###### AST Total

<div class="wrapper" style="max-width: 90%; margin: auto">
    <canvas id="chart-num-bar-ast"></canvas>
</div>

##### Inheritance Graph

<a onclick="toggleVisibility('surya-inherit', this)">[➕]</a>
<div id="surya-inherit" style="display:none">
<div class="wrapper" style="max-width: 512px; margin: auto">
    <div id="surya-inheritance" style="text-align: center;"></div> 
</div>
</div>

##### CallGraph

<a onclick="toggleVisibility('surya-call', this)">[➕]</a>
<div id="surya-call" style="display:none">
<div class="wrapper" style="max-width: 512px; margin: auto">
    <div id="surya-callgraph" style="text-align: center;"></div>
</div>
</div>

###### Contract Summary

<a onclick="toggleVisibility('surya-mdreport', this)">[➕]</a>
<div id="surya-mdreport" style="display:none">
 Sūrya's Description Report

 Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./contracts/oracles/OracleManager.sol | 3b665cd222b4d13b8c18c20383d934c0cdba9b26 |
| ./contracts/YieldManagers/MarketLiquidityManagerSimple.sol | 9ed50ffce2293f80004f554aaffcafb4c2744b2d |
| ./contracts/market/template/MarketExtended.sol | bd644dc55dbed886cd138f78f46365a8bf02fd4d |
| ./contracts/market/template/MarketCore.sol | 1367879ac11b0c76dacc33f93630650779c4456a |
| ./contracts/PoolToken/PoolToken.sol | cf413b6f19a45f5fcb5d36e6e0823c618aa81b5d |


 Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **OracleManager** | Implementation | IOracleManager |||
| └ | <Constructor> | Public ❗️ | 🛑  |NO❗️ |
| └ | getEpochStartTimestamp | Public ❗️ |   |NO❗️ |
| └ | getCurrentEpochIndex | External ❗️ |   |NO❗️ |
| └ | validateAndReturnMissedEpochInformation | Public ❗️ |   |NO❗️ |
||||||
| **MarketLiquidityManagerSimple** | Implementation | ILiquidityManager, AccessControlledAndUpgradeable |||
| └ | <Constructor> | Public ❗️ | 🛑  | initializer |
| └ | initialize | External ❗️ | 🛑  | initializer |
| └ | transferPaymentTokensToUser | External ❗️ | 🛑  | marketOnly |
||||||
| **MarketExtendedCore** | Implementation | AccessControlledAndUpgradeableModifiers, MarketStorage, IMarketExtendedCore |||
| └ | <Constructor> | Public ❗️ | 🛑  | initializer MarketStorage |
| └ | initializePools | External ❗️ | 🛑  | initializer |
| └ | updateMarketOracle | External ❗️ | 🛑  | adminOnly |
| └ | changeMarketFundingRateMultiplier | External ❗️ | 🛑  | adminOnly |
| └ | changeStabilityFeeBasisPoints | External ❗️ | 🛑  | adminOnly |
| └ | _addPoolToExistingMarket | Internal 🔒 | 🛑  | |
| └ | addPoolToExistingMarket | External ❗️ | 🛑  | adminOnly |
| └ | pauseMinting | External ❗️ | 🛑  | adminOnly |
| └ | unpauseMinting | External ❗️ | 🛑  | adminOnly |
||||||
| **MarketCore** | Implementation | AccessControlledAndUpgradeableModifiers, IMarketCommon, IMarketCore, MarketStorage, ProxyNonPayable |||
| └ | gemCollectingModifierLogic | Internal 🔒 | 🛑  | |
| └ | _calculateFundingAmount | Internal 🔒 |   | |
| └ | _getValueChangeAndFunding | Internal 🔒 |   | |
| └ | _rebalancePoolsAndExecuteBatchedActions | Internal 🔒 | 🛑  | |
| └ | updateSystemStateUsingValidatedOracleRoundIds | External ❗️ | 🛑  | checkMarketNotDeprecated |
| └ | _calculateStabilityFees | Internal 🔒 |   | |
| └ | _mint | Internal 🔒 | 🛑  | |
| └ | mintLong | External ❗️ | 🛑  | gemCollecting |
| └ | mintShort | External ❗️ | 🛑  | gemCollecting |
| └ | mintFloatPool | External ❗️ | 🛑  |NO❗️ |
| └ | mintLongFor | External ❗️ | 🛑  | gemCollecting |
| └ | mintShortFor | External ❗️ | 🛑  | gemCollecting |
| └ | _redeem | Internal 🔒 | 🛑  | checkMarketNotDeprecated |
| └ | redeemLong | External ❗️ | 🛑  | gemCollecting |
| └ | redeemShort | External ❗️ | 🛑  | gemCollecting |
| └ | redeemFloatPool | External ❗️ | 🛑  |NO❗️ |
| └ | settlePoolUserMints | Public ❗️ | 🛑  |NO❗️ |
| └ | settlePoolUserRedeems | Public ❗️ | 🛑  |NO❗️ |
| └ | _handleChangeInPoolTokensTotalSupply | Internal 🔒 | 🛑  | |
| └ | _processAllBatchedEpochActions | Internal 🔒 | 🛑  | |
| └ | _deprecateMarket | Internal 🔒 | 🛑  | |
| └ | deprecateMarketNoOracleUpdates | External ❗️ | 🛑  |NO❗️ |
| └ | deprecateMarket | External ❗️ | 🛑  | adminOnly |
| └ | _exitDeprecatedMarket | Internal 🔒 | 🛑  | |
| └ | exitDeprecatedMarket | External ❗️ | 🛑  |NO❗️ |
| └ | <Constructor> | Public ❗️ | 🛑  | initializer MarketStorage |
| └ | _implementation | Internal 🔒 |   | |
||||||
| **PoolToken** | Implementation | AccessControlledAndUpgradeable, ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PermitUpgradeable, IPoolToken |||
| └ | <Constructor> | Public ❗️ | 🛑  | initializer |
| └ | initialize | External ❗️ | 🛑  | initializer |
| └ | totalSupply | Public ❗️ |   |NO❗️ |
| └ | mint | External ❗️ | 🛑  | onlyRole |
| └ | burn | Public ❗️ | 🛑  | onlyRole |
| └ | transferFrom | Public ❗️ | 🛑  |NO❗️ |
| └ | transfer | Public ❗️ | 🛑  |NO❗️ |
| └ | _beforeTokenTransfer | Internal 🔒 | 🛑  | |
| └ | balanceOf | Public ❗️ |   |NO❗️ |


 Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
 

</div>
____
<sub>
Thinking about smart contract security? We can provide training, ongoing advice, and smart contract auditing. [Contact us](https://diligence.consensys.net/contact/).
</sub>

