/// NOTE: this file doesn't currently generate the AST - so isn't completely useful currently.
const path = require("path");
const fs = require("fs-extra");
const solc = require("solc");

const buildPathAbi = path.resolve(__dirname, "../build/abis");
const buildPathAst = path.resolve(__dirname, "../build/ast");

// Compile contract
const contractPathMarketTieredLeverage = path.resolve("./contracts/market/template", "MarketTieredLeverage.sol");
const sourceMarketTieredLeverage = fs.readFileSync(contractPathMarketTieredLeverage, "utf8");

const abiOnlyCode = [
  {
    path: "./contracts/upgrades/", name: "UpgradeMarkets"
  },
  {
    path: "./contracts/longShort/template/", name: "LongShort"
  },
  {
    path: "./contracts/market/template/", name: "MarketTieredLeverage"
  },
  {
    path: "./contracts/", name: "AlphaTestFLT"
  },
  {
    path: "./contracts/", name: "FloatCapital_v0"
  },
  {
    path: "./contracts/", name: "FloatToken"
  },
  {
    path: "./contracts/", name: "Treasury_v0"
  },
  {
    path: "./contracts/", name: "TreasuryAlpha"
  },
  {
    path: "./contracts/", name: "KeeperArctic"
  },
  {
    path: "./contracts/", name: "GEMS"
  }, {
    path: "./contracts/", name: "GemCollectorNFT"
  },
  { path: "./contracts/MIA/", name: "PoolTokenMarketUpgradeable" },
  { path: "./contracts/mocks/", name: "AaveIncentivesControllerMock" },
  { path: "./contracts/mocks/", name: "LendingPoolAddressesProvider" },
  { path: "./contracts/mocks/", name: "AggregatorV3Mock" },
  { path: "./contracts/mocks/", name: "OracleManagerBasicFollowingPriceMock" },
  { path: "./contracts/mocks/", name: "ChainlinkAggregatorFaster" },
  { path: "./contracts/mocks/", name: "OracleManagerMock" },
  { path: "./contracts/mocks/", name: "OracleManagerNthPriceMock" },
  { path: "./contracts/mocks/", name: "ERC20Mock" },
  { path: "./contracts/mocks/", name: "YieldManagerMock" },
  { path: "./contracts/mocks/", name: "LendingPoolAaveMock" },
  { path: "./contracts/oracles", name: "OracleManagerChainlink" },
  { path: "./contracts/oracles", name: "OracleManagerChainlinkTestnet" },
  { path: "./contracts/oracles/template", name: "OracleManagerFixedEpoch" },
  { path: "./contracts/v0.1/longShort/template/", name: "LongShortOriginal" },
  { path: "./contracts/v0.1/MIA/", name: "SlowTradeSyntheticTokenUpgradeable" },
  { path: "./contracts/v0.1/MIA/", name: "SyntheticTokenOriginal" },
  { path: "./contracts/v0.1/MIA/", name: "SyntheticTokenUpgradeableOriginal" },
  { path: "./contracts/v0.1/mocks/", name: "YieldManagerMockOriginal" },
  { path: "./contracts/v0.1/staker/template/", name: "Staker" },
  { path: "./contracts/YieldManagers/", name: "DefaultYieldManagerAave" },
  { path: "./contracts/YieldManagers/", name: "DefaultYieldManagerAaveV3" },
  { path: "./contracts/YieldManagers/", name: "DefaultYieldManagerCompound" },
  { path: "./contracts/YieldManagers/", name: "YieldManagerAaveBasic" },
]

const sources = {
  "AST.MarketTieredLeverage.sol": {
    content: sourceMarketTieredLeverage,
  },
}

abiOnlyCode.forEach(({ path: filePath, name }) => {
  sources[`${name}.sol`] = {
    content: fs.readFileSync(
      path.resolve(`${filePath}`, `${name}.sol`)
      , "utf8"),
  };
})

const input = {
  language: "Solidity",
  sources: sources,
  settings: {
    outputSelection: {
      "*": {
        "*": ["abi"],
        "": [
          "ast", // Enable the AST output of every single file.
        ],
      },
    },
    optimizer: {
      // disabled by default
      enabled: false,
      // Optimize for how many times you intend to run the code.
      // Lower values will optimize more for initial deployment cost, higher values will optimize more for high-frequency usage.
      // runs: 1,
    },
    evmVersion: "london", // Version of the EVM to compile for. Affects type checking and code generation. Can be homestead, tangerineWhistle, spuriousDragon, byzantium or constantinople
  },
};

const result = JSON.parse(
  solc.compile(JSON.stringify(input), { import: findImports })
);

console.log("compilation errors:");
console.log(result.errors);
for (let contractName in result.contracts) {
  console.log("build", buildPathAbi);
  let contractNameNoExtension = contractName.replace(".sol", "");
  console.log("contractname", contractNameNoExtension);
  let fileName = contractNameNoExtension.split("/");
  let finalFileName = fileName[fileName.length - 1];
  console.log("filename", finalFileName);
  if (!!result.contracts[contractName][finalFileName]) {
    fs.outputJsonSync(
      path.resolve(buildPathAbi, `${contractNameNoExtension}.json`),
      result.contracts[contractName][finalFileName].abi
    );
  }
  fs.outputJsonSync(
    path.resolve(buildPathAst, `${contractNameNoExtension}.json`),
    result.sources[contractName].ast
  );
}

function findImports(path) {
  let sourceCodeToImport;
  if (path[0] === "@") {
    // directly into node_ module
    sourceCodeToImport = fs.readFileSync(`./node_modules/${path}`);
    return { contents: `${sourceCodeToImport}` };
  } else if (path.includes("forge-std") || path.includes("hardhat")) {
    sourceCodeToImport = fs.readFileSync(`./node_modules/${path}`);
    return { contents: `${sourceCodeToImport}` };
  } else {
    sourceCodeToImport = fs.readFileSync(`./contracts/${path}`);
    return { contents: `${sourceCodeToImport}` };
  }
}
