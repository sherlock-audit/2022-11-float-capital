// Converting this file to typescript was not working, so leaving this as javascript for now.

require("@typechain/hardhat");
require("hardhat-spdx-license-identifier");
require("./hardhat-plugins/codegen");
require("@primitivefi/hardhat-dodoc");
require("hardhat-output-validator");

const {
  TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS,
} = require("hardhat/builtin-tasks/task-names");

try {
  require("./test/Setup.js").mochaSetup();
} catch (e) {
  console.warn(
    "You need to generate the rescript contracts, this could cause tests to fail."
  );
}

let config;
try {
  config = require("./secretsManager.js");
} catch (e) {
  console.error(
    "You are using the example secrets manager, please copy this file if you want to use it"
  );
  config = require("./secretsManager.example.js");
}

const {
  mnemonic,
  mainnetProviderUrl,
  rinkebyProviderUrl,
  kovanProviderUrl,
  goerliProviderUrl,
  etherscanApiKey,
  polygonscanApiKey,
  mumbaiProviderUrl,
  polygonProviderUrl,
  avalancheProviderUrl,
} = config;

let runCoverage =
  !process.env.DONT_RUN_REPORT_SUMMARY ||
  process.env.DONT_RUN_REPORT_SUMMARY.toUpperCase() != "TRUE";
if (runCoverage) {
  require("hardhat-abi-exporter");
  require("hardhat-gas-reporter");
}
// let isWaffleTest =
//   !!process.env.WAFFLE_TEST && process.env.WAFFLE_TEST.toUpperCase() == "TRUE";
// if (isWaffleTest) {

// This is a sample Buidler task. To learn how to create your own go to
// https://buidler.dev/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(await account.getAddress());
  }
});

// While waiting for hardhat PR: https://github.com/nomiclabs/hardhat/pull/1542
if (process.env.HARDHAT_FORK) {
  process.env["HARDHAT_DEPLOY_FORK"] = process.env.HARDHAT_FORK;
}

// try use forge config
let foundry;
const SOLC_DEFAULT = "0.8.17";
try {
  foundry = toml.parse(readFileSync("./foundry.toml").toString());
  foundry.default.solc = foundry.default["solc-version"]
    ? foundry.default["solc-version"]
    : SOLC_DEFAULT;
} catch (error) {
  foundry = {
    default: {
      solc: SOLC_DEFAULT,
    },
  };
}

// prune forge style tests from hardhat paths
subtask(TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS).setAction(
  async (_, __, runSuper) => {
    const paths = await runSuper();
    return paths.filter(
      (p) =>
        !p.endsWith(".t.sol") &&
        !p.endsWith(".scenario.sol") &&
        !p.endsWith(".u.sol") &&
        !p.endsWith(".s.sol")
    );
  }
);

// You have to export an object to set up your config
// This object can have the following optional entries:
// defaultNetwork, networks, solc, and paths.
// Go to https://buidler.dev/config/ to learn more
console.log(mumbaiProviderUrl);
module.exports = {
  solidity: {
    version: foundry.default.solc,
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defaultNetwork: "hardhat",
  paths: {
    tests: "./test",
  },
  namedAccounts: {
    deployer: 0,
    admin: 1,
    user1: 2,
    user2: 3,
    user3: 4,
    user4: 5,
    discountSigner: 6,
  },
  spdxLicenseIdentifier: {
    // Set these to true if you ever want to change the licence on all of the contracts (by changing it in package.json)
    overwrite: false,
    runOnCompile: false,
  },
  abiExporter: {
    // TODO: make the graph reliant on abi's from `forge build` output instead!
    path: "./abis",
    clear: true,
    runOnCompile: true,
    flat: true,
    only: [
      ":ERC20Mock$",
      ":LongShortOriginal$",
      ":LongShort$",
      ":SyntheticTokenUpgradeable$",
      ":FloatCapital_v0$",
      ":Market$",
      ":TokenFactory$",
      ":FloatToken$",
      ":OracleManagerBasicFollowingPriceMock$",
      ":MarketCore$",
      ":MarketExtended$",
      ":OracleManager$",
      ":Treasury_v0$",
      ":GemCollectorNFT$",
      ":OracleManagerMock$",
      ":YieldManagerAaveBasic$",
      ":GEMS$",
      ":SyntheticToken$",
      ":PoolToken$",
      ":YieldManagerMock$",
    ],
    spacing: 2,
  },
  dodoc: {
    runOnCompile: false,
    debugMode: true,
  },
  etherscan: {
    apiKey: polygonscanApiKey,
  },
  outputValidator: {
    runOnCompile: true,
    errorMode: true,
    checks: {
      title: "error",
      details: "error",
      params: "error",
      returns: "error",
      compilationWarnings: "warning",
      variables: true,
      events: true,
    },
    exclude: [
      "*.t.sol",
      "*.s.sol",
      "contracts/util",
      "contracts/v0.1ImportantCode",
      "contracts/testing",
      "contracts/scripts",
      "contracts/mocks",
      // Below are files we should document but aren't important for audit.
      "contracts/shifting",
      "contracts/registry",
      "contracts/market/template/inconsequentialViewFunctions"
    ],
  },
};
