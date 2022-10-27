// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "../../keepers/KeeperArctic.sol";
import "../../interfaces/IMarket.sol";
import "../../interfaces/IMarket.sol";
import "../../registry/template/Registry.sol";
import "../../oracles/OracleManager.sol";
import "../../testing/Constants.t.sol";
import "../../scripts/util/FFIHelpers.s.sol";

library DeployedContractsAddressPrinter {
  function getAddresses(IRegistry registry) external view {
    console2.log("Registry:", address(registry));

    uint32 numberOfMarkets = registry.latestMarket();

    for (uint32 marketIndex = 1; marketIndex <= numberOfMarkets; marketIndex++) {
      IMarket market = IMarket(registry.separateMarketContracts(marketIndex));
      console2.log("\nMarket Index:", marketIndex, "\naddress:", address(market));

      console2.log("liquidityManager:", market.get_liquidityManager());
      IOracleManager oracleManager = market.get_oracleManager();
      console2.log("oracleManager:", address(oracleManager));

      address chainlinkOracle = address(oracleManager.chainlinkOracle());
      uint256 initialEpochStartTimestamp = oracleManager.initialEpochStartTimestamp();
      uint256 MINIMUM_EXECUTION_WAIT_THRESHOLD = oracleManager.MINIMUM_EXECUTION_WAIT_THRESHOLD();
      uint256 EPOCH_LENGTH = oracleManager.EPOCH_LENGTH();
      console2.log("initialEpochStartTimestamp:", initialEpochStartTimestamp);
      console2.log("MINIMUM_EXECUTION_WAIT_THRESHOLD:", MINIMUM_EXECUTION_WAIT_THRESHOLD, "EPOCH_LENGTH:", EPOCH_LENGTH);
      address paymentToken = market.get_paymentToken();
      console2.log("Payment Token: ", paymentToken);

      uint256 numberLongPools = market.numberOfPoolsOfType(IMarketCommon.PoolType.LONG);
      uint256 numberShortPools = market.numberOfPoolsOfType(IMarketCommon.PoolType.SHORT);

      console2.log("\n\nLONG POOLS \n\nNumber of long pools:", numberLongPools);

      for (uint256 poolIndex = 0; poolIndex < numberLongPools; poolIndex++) {
        address token = market.get_pool_token(IMarketCommon.PoolType.LONG, poolIndex);
        int96 leverage = market.get_pool_leverage(IMarketCommon.PoolType.LONG, poolIndex);
        uint256 value = market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndex);
        console2.log("\nLong Pool #:", poolIndex, "Token:", token);
        console2.log("Value:", value, "Leverage:", uint96(leverage > 0 ? leverage : -leverage));
      }

      console2.log("\n\nSHORT POOLS \n\nNumber of short pools:", numberLongPools);

      for (uint256 poolIndex = 0; poolIndex < numberShortPools; poolIndex++) {
        address token = market.get_pool_token(IMarketCommon.PoolType.SHORT, poolIndex);
        int96 leverage = market.get_pool_leverage(IMarketCommon.PoolType.SHORT, poolIndex);
        uint256 value = market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndex);
        console2.log("\nShort Pool #:", poolIndex, "Token:", token);
        console2.log("Value:", value, "Leverage:", uint96(leverage > 0 ? leverage : -leverage));
      }
    }
  }

  // Constants constants = new Constants();
  // mapping(uint256 => string) chainIdToApiKeyEnvVar;
  // chainIdToApiKeyEnvVar[8001];

  function getVerificationCmd(
    Vm vm,
    string memory contractName,
    address contractAddress,
    string memory apiKeyEnvVar,
    bool isLastCommand
  ) public returns (string memory cmd) {
    //forge verify-contract --watch --flatten --chain-id 43113  0x7262f8b1ced59dd83B37677798A27ad58bD1001b OracleManagerUtils $SNOWTRACE_API_KEY

    cmd = string.concat(
      "forge verify-contract --watch --flatten --chain-id ",
      vm.toString(block.chainid),
      " ",
      vm.toString(contractAddress),
      " ",
      contractName,
      " ",
      apiKeyEnvVar,
      isLastCommand ? "" : " ;\\"
    );

    console2.log(cmd);

    // if (shouldExecuteWithFfi) {
    //   // string[] memory inputstest = new string[](1);

    //   // inputstest[0] = "pwd";

    //   // console2.log(string(vm.ffi(inputstest)));
    //   string[] memory inputs = new string[](12);

    //   inputs[0] = "source";
    //   inputs[1] = ".env";
    //   inputs[2] = "&&";
    //   inputs[3] = "forge";
    //   inputs[4] = "verify-contract";
    //   inputs[5] = "--watch";
    //   inputs[6] = "--flatten";
    //   inputs[7] = "--chain-id";
    //   inputs[8] = vm.toString(block.chainid);
    //   inputs[9] = vm.toString(contractAddress);
    //   inputs[10] = contractName;
    //   inputs[11] = apiKeyEnvVar;

    //   vm.ffi(inputs);
    // }
  }

  function printAllVerificationCmds(
    Vm vm,
    string memory contractName,
    address contractAddress,
    string memory apiKeyEnvVar,
    bool isLastCommand
  ) public {
    bytes32 _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address originalImplementation = address(uint160(uint256(vm.load(contractAddress, _IMPLEMENTATION_SLOT))));
    // if above address is not a proxy, verify both...
    string memory cmd;

    if (originalImplementation == address(0)) {
      cmd = getVerificationCmd(vm, contractName, contractAddress, apiKeyEnvVar, isLastCommand);
      // if (shouldExecuteWithFfi) {
      //   FFIHelpers.executeCmdString(vm, cmd);
      // }
    } else {
      cmd = getVerificationCmd(vm, contractName, originalImplementation, apiKeyEnvVar, false);
      // if (shouldExecuteWithFfi) {
      //   FFIHelpers.executeCmdString(vm, cmd);
      // }
      cmd = getVerificationCmd(vm, "ERC1967Proxy", contractAddress, apiKeyEnvVar, isLastCommand);
      // if (shouldExecuteWithFfi) {
      //   FFIHelpers.executeCmdString(vm, cmd);
      // }
    }
  }

  //proxy.nonCoreFunctionsDelegatee(), check for marketExtended

  function getVerificationCommand(
    IRegistry registry,
    KeeperArctic keeper,
    Vm vm,
    string memory apiKeyEnvVar
  ) external {
    uint32 numberOfMarkets = registry.latestMarket();
    bool isLastCommand = true;
    // console2.log("forge flatten lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol -o flattenedContracts/ERC1967Proxy.sol;");
    // console2.log(
    //   "forge flatten contracts/market/template/inconsequentialViewFunctions/MarketWithAdditionalViewFunctions.sol -o flattenedContracts/Market.sol"
    // );
    // console2.log("forge flatten contracts/keepers/KeeperArctic.sol -o flattenedContracts/KeeperArctic.sol");
    // console2.log("forge flatten contracts/registry/template/Registry.sol -o flattenedContracts/Registry.sol");
    // console2.log("forge flatten contracts/POOLTOKEN/PoolToken.sol -o flattenedContracts/PoolToken.sol");
    // console2.log("forge flatten contracts/components/gamificationFun/GEMS.sol -o flattenedContracts/gamificationFun/GEMS.sol");
    console2.log("forge flatten contracts/util/AllContractsFlat.sol -o flattenedContracts/All.sol");
    console2.log("export FOUNDRY_PROFILE=verify");
    console2.log("forge build");

    printAllVerificationCmds(vm, "KeeperArctic", address(keeper), apiKeyEnvVar, !isLastCommand);
    printAllVerificationCmds(vm, "Registry", address(registry), apiKeyEnvVar, !isLastCommand);

    for (uint32 marketIndex = 1; marketIndex <= numberOfMarkets; marketIndex++) {
      address marketAddress = registry.separateMarketContracts(marketIndex);
      MarketCore MarketCore = MarketCore(marketAddress);
      address marketExtendedAddress = address(MarketCore.nonCoreFunctionsDelegatee());

      IMarket market = IMarket(registry.separateMarketContracts(marketIndex));
      printAllVerificationCmds(vm, "Market", marketAddress, apiKeyEnvVar, !isLastCommand);
      printAllVerificationCmds(vm, "MarketExtended", marketExtendedAddress, apiKeyEnvVar, !isLastCommand);
      {
        address gems = market.get_gems();
        printAllVerificationCmds(vm, "GEMS", gems, apiKeyEnvVar, !isLastCommand);
      }
      // console2.log("liquidityManager:", market.get_liquidityManager());
      // printAllVerificationCmds(vm, "liquidityManager", marketExtendedAddress, apiKeyEnvVar, !isLastCommand);

      // address chainlinkOracle = address(oracleManager.chainlinkOracle());
      // uint8 oracleDecimals = oracleManager.oracleDecimals();
      // uint256 initialEpochStartTimestamp = oracleManager.initialEpochStartTimestamp();
      // uint256 MINIMUM_EXECUTION_WAIT_THRESHOLD = oracleManager.MINIMUM_EXECUTION_WAIT_THRESHOLD();
      // uint256 EPOCH_LENGTH = oracleManager.EPOCH_LENGTH();
      // console2.log("chainlinkOracle:", chainlinkOracle, "oracleDecimals:", oracleDecimals);
      // console2.log("initialEpochStartTimestamp:", initialEpochStartTimestamp);
      // console2.log("MINIMUM_EXECUTION_WAIT_THRESHOLD:", MINIMUM_EXECUTION_WAIT_THRESHOLD, "EPOCH_LENGTH:", EPOCH_LENGTH);

      uint256 numberLongPools = market.numberOfPoolsOfType(IMarketCommon.PoolType.LONG);
      uint256 numberShortPools = market.numberOfPoolsOfType(IMarketCommon.PoolType.SHORT);

      // console2.log("\n\nLONG POOLS \n\nNumber of long pools:", numberLongPools);

      for (uint256 poolIndex = 0; poolIndex < numberLongPools; poolIndex++) {
        address token = market.get_pool_token(IMarketCommon.PoolType.LONG, poolIndex);
        printAllVerificationCmds(vm, "PoolToken", token, apiKeyEnvVar, !isLastCommand);
        // int96 leverage = market.get_pool_leverage(IMarketCommon.PoolType.LONG, poolIndex);
        // uint256 value = market.get_pool_value(IMarketCommon.PoolType.LONG, poolIndex);
        // console2.log("\nLong Pool #:", poolIndex, "Token:", token);
        // console2.log("Value:", value, "Leverage:", uint96(leverage > 0 ? leverage : -leverage));
      }

      // console2.log("\n\nSHORT POOLS \n\nNumber of short pools:", numberLongPools);

      for (uint256 poolIndex = 0; poolIndex < numberShortPools; poolIndex++) {
        address token = market.get_pool_token(IMarketCommon.PoolType.SHORT, poolIndex);
        printAllVerificationCmds(vm, "PoolToken", token, apiKeyEnvVar, !isLastCommand);
        // int96 leverage = market.get_pool_leverage(IMarketCommon.PoolType.SHORT, poolIndex);
        // uint256 value = market.get_pool_value(IMarketCommon.PoolType.SHORT, poolIndex);
        // console2.log("\nShort Pool #:", poolIndex, "Token:", token);
        // console2.log("Value:", value, "Leverage:", uint96(leverage > 0 ? leverage : -leverage));
      }
      {
        IOracleManager oracleManager = market.get_oracleManager();
        // console2.log("oracleManager:", address(oracleManager));
        printAllVerificationCmds(vm, "OracleManager", address(oracleManager), apiKeyEnvVar, isLastCommand);
      }
    }
    console2.log("export FOUNDRY_PROFILE=default");
  }

  function getVerificationLink(
    Vm vm,
    address contractAddress,
    string memory etherscanUrl
  ) public returns (string memory cmd) {
    // v0.8.17%2bcommit.8df45f5f
    // v0.8.16%2bcommit.07a7930e
    cmd = string.concat(etherscanUrl, "/verifyContract-solc?a=", vm.toString(contractAddress), "&c=v0.8.17%2bcommit.8df45f5f&lictype=14");

    console2.log(cmd);
  }

  function printAllVerificationLinks(
    Vm vm,
    address contractAddress,
    string memory etherscanUrl
  ) public {
    bytes32 _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address originalImplementation = address(uint160(uint256(vm.load(contractAddress, _IMPLEMENTATION_SLOT))));

    getVerificationLink(vm, contractAddress, etherscanUrl);
    // if above address is not a proxy, verify both...
    if (originalImplementation != address(0)) getVerificationLink(vm, originalImplementation, etherscanUrl);
  }

  function getVerificationLinks(
    IRegistry registry,
    KeeperArctic keeper,
    Vm vm,
    string memory etherscanUrl
  ) external {
    uint32 numberOfMarkets = registry.latestMarket();

    console2.log("******************\nINSTRUCTIONS\n******************\n");
    console2.log("Run this command: `forge flatten contracts/util/AllContractsFlat.sol -o flattenedContracts/All.sol`");
    console2.log("Then open each of the links below and past the full contents of `flattenedContracts/All.sol` into the verification window");

    console2.log("Keeper:");
    printAllVerificationLinks(vm, address(keeper), etherscanUrl);
    console2.log("Registry:");
    printAllVerificationLinks(vm, address(registry), etherscanUrl);

    for (uint32 marketIndex = 1; marketIndex <= numberOfMarkets; marketIndex++) {
      address marketAddress = registry.separateMarketContracts(marketIndex);
      MarketCore MarketCore = MarketCore(marketAddress);
      address marketExtendedAddress = address(MarketCore.nonCoreFunctionsDelegatee());

      IMarket market = IMarket(registry.separateMarketContracts(marketIndex));

      if (marketIndex == 1) {
        // Only need to verify gems once since common between all markets.
        address gems = market.get_gems();
        console2.log("Gems:");
        printAllVerificationLinks(vm, gems, etherscanUrl);
      }

      console2.log("Market:");
      printAllVerificationLinks(vm, marketAddress, etherscanUrl);
      console2.log("Market (extended):");
      printAllVerificationLinks(vm, marketExtendedAddress, etherscanUrl);

      uint256 numberLongPools = market.numberOfPoolsOfType(IMarketCommon.PoolType.LONG);
      uint256 numberShortPools = market.numberOfPoolsOfType(IMarketCommon.PoolType.SHORT);

      console2.log("Pool Tokens long:");
      for (uint256 poolIndex = 0; poolIndex < numberLongPools; poolIndex++) {
        address token = market.get_pool_token(IMarketCommon.PoolType.LONG, poolIndex);
        printAllVerificationLinks(vm, token, etherscanUrl);
      }

      console2.log("Pool Tokens Short:");
      for (uint256 poolIndex = 0; poolIndex < numberShortPools; poolIndex++) {
        address token = market.get_pool_token(IMarketCommon.PoolType.SHORT, poolIndex);
        printAllVerificationLinks(vm, token, etherscanUrl);
      }
      {
        IOracleManager oracleManager = market.get_oracleManager();
        printAllVerificationLinks(vm, address(oracleManager), etherscanUrl);
      }
    }
    console2.log("export FOUNDRY_PROFILE=default");
  }
}

contract PrintAddressesFromKeeper is Script, Test, Constants {
  KeeperArctic keeper;
  IRegistry registry = IRegistry(0xfb98538a6B20D71928818bD0a665EC4f82114361);

  address constant keeperMumbaiAddress = 0x537f6Dd8C645FDeb4BBEEb964d9128b1751E3122;

  function run() external {
    vm.startBroadcast();

    if (block.chainid == CHAIN_ID_MUMBAI) {
      keeper = KeeperArctic(KEEPER_MUMBAI_ADDRESS);
    } else if (block.chainid == CHAIN_ID_FUJI) {
      keeper = KeeperArctic(KEEPER_FUJI_ADDRESS);
    } else {
      console2.log("You are on chainid:", block.chainid);
      revert("unrecognised network:");
    }

    registry = keeper.registry();

    DeployedContractsAddressPrinter.getAddresses(registry);
  }
}

contract PrintVerificationCmdsFromKeeper is Script, Test, Constants {
  KeeperArctic keeper;
  IRegistry registry = IRegistry(0xfb98538a6B20D71928818bD0a665EC4f82114361);

  mapping(uint256 => string) chainIdToApiKeyEnvVar;

  constructor() {
    chainIdToApiKeyEnvVar[CHAIN_ID_MUMBAI] = "$POLYGONSCAN_API_KEY";
    chainIdToApiKeyEnvVar[CHAIN_ID_FUJI] = "$SNOWTRACE_API_KEY";
  }

  function run() external {
    vm.startBroadcast();

    if (block.chainid == CHAIN_ID_MUMBAI) {
      keeper = KeeperArctic(KEEPER_MUMBAI_ADDRESS);
    } else if (block.chainid == CHAIN_ID_FUJI) {
      keeper = KeeperArctic(KEEPER_FUJI_ADDRESS);
    } else {
      console2.log("You are on chainid:", block.chainid);
      revert("unrecognised network:");
    }

    registry = keeper.registry();

    DeployedContractsAddressPrinter.getVerificationCommand(registry, keeper, vm, chainIdToApiKeyEnvVar[block.chainid]);
  }
}

contract PrintVerificationLinksFromKeeper is Script, Test, Constants {
  KeeperArctic keeper;
  IRegistry registry = IRegistry(0xfb98538a6B20D71928818bD0a665EC4f82114361);

  mapping(uint256 => string) chainIdToEtherscanLink;

  constructor() {
    chainIdToEtherscanLink[CHAIN_ID_MUMBAI] = "https://mumbai.polygonscan.com";
    chainIdToEtherscanLink[CHAIN_ID_POLYGON] = "https://polygonscan.com";
    chainIdToEtherscanLink[CHAIN_ID_FUJI] = "https://testnet.snowtrace.io";
  }

  function run() external {
    vm.startBroadcast();

    if (block.chainid == CHAIN_ID_MUMBAI) {
      keeper = KeeperArctic(KEEPER_MUMBAI_ADDRESS);
    } else if (block.chainid == CHAIN_ID_FUJI) {
      keeper = KeeperArctic(KEEPER_FUJI_ADDRESS);
    } else {
      console2.log("You are on chainid:", block.chainid);
      revert("unrecognised network:");
    }

    registry = keeper.registry();

    DeployedContractsAddressPrinter.getVerificationLinks(registry, keeper, vm, chainIdToEtherscanLink[block.chainid]);
  }
}
