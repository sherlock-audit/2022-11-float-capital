/*
// SPDX-License-Identifier: BUSL-1.1
//Used to test the graph on Anvil
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "ds-test/test.sol";

import "../keepers/KeeperArctic.sol";
import "../components/gamificationFun/GEMS.sol";
import "../registry/template/Registry.sol";
import "../PoolToken/PoolToken.sol";
import "../oracles/OracleManager.sol";
import "../interfaces/IMarket.sol";
import "../testing/dev/UpgradeTester.sol";
import "../mocks/ChainlinkAggregatorFaster.sol";
import "../PoolToken/PoolToken.sol";
import "../mocks/ChainlinkAggregatorRandomScribble.sol";

import "../testing/FloatContractsCoordinator.s.sol";

contract MyScript is FloatContractsCoordinator {
  bytes32 constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  // KeeperArctic keeper;
  PaymentTokenTestnet paymentToken;
  AggregatorV3Mock v3MockOracle;

  address constant ethOracleAnvilAddress = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;

  address constant keeperAnvilAddress = 0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0;

  address constant registryAnvil = 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707;

  address constant paymentTokenAnvil = 0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6;

  constructor() {
    registry = Registry(registryAnvil);
    keeper = KeeperArctic(keeperAnvilAddress);
    paymentToken = PaymentTokenTestnet(paymentTokenAnvil);
    v3MockOracle = AggregatorV3Mock(ethOracleAnvilAddress);
  }

  function mint(
    address user,
    uint256 pool,
    uint32 marketIndex,
    uint112 amount,
    bool isLong
  ) internal {
    if (isLoggingOn) {
      console2.log("*********");
      console2.log(isLong ? "Random MINT: LONG" : "Random MINT: SHORT", user, "marketInde", marketIndex);
      console2.log("amount", amount, "pool", pool);
      console2.log("*********");
    }
    Market marketInstance = Market(registry.separateMarketContracts(marketIndex));

    if (isLong) {
      marketInstance.mintLong(pool, amount);
    } else {
      marketInstance.mintShort(pool, amount);
    }
  }

  function redeem(
    address user,
    uint256 pool,
    uint32 marketIndex,
    uint112 amount,
    bool isLong
  ) internal {
    if (isLoggingOn) {
      console2.log("*********");
      console2.log(isLong ? "Random REDEEM: LONG" : "Random REDEEM: SHORT", user, "marketInde", marketIndex);
      console2.log("amount", amount, "pool", pool);
      console2.log("*********");
    }
    Market marketInstance = Market(registry.separateMarketContracts(marketIndex));

    updateSystemStateSingleMarket(marketIndex);

    if (isLong) {
      marketInstance.redeemLong(pool, amount);
    } else {
      marketInstance.redeemShort(pool, amount);
    }
  }

  function userMint(
    uint32 marketIndex,
    uint256 pool,
    bool isLong
  ) internal {
    v3MockOracle.pushPricePercentMovement(1e16);
    paymentToken.mint(5e21);
    paymentToken.approve(address(registry.separateMarketContracts(marketIndex)), ~uint256(0));
    uint256 paymentTokenBalance = paymentToken.balanceOf(msg.sender);
    if (paymentTokenBalance > 1e18) {
      mint(msg.sender, pool, marketIndex, uint112(1e18), isLong);
    }
  }

  function userRedeem(
    uint32 marketIndex,
    uint256 pool,
    bool isLong
  ) internal {
    vm.startBroadcast();
    v3MockOracle.pushPricePercentMovement(1e16);
    Market marketInstance = Market(registry.separateMarketContracts(marketIndex));

    uint256 poolTokenBalance;
    {
      address poolTokenTokenAddresss = marketInstance.get_pool_token(isLong ? IMarketCommon.PoolType.LONG : IMarketCommon.PoolType.SHORT, pool);

      poolTokenBalance = IERC20(poolTokenTokenAddresss).balanceOf(msg.sender);
    }

    if (poolTokenBalance > 0) {
      redeem(msg.sender, pool, marketIndex, uint112(poolTokenBalance), isLong);
    }
    vm.stopBroadcast();
  }

  function runTestMints() public {
    vm.startBroadcast();

    userMint(1, 0, true);
    userMint(1, 0, false);
    userMint(1, 1, true);
    userMint(1, 1, false);
    vm.stopBroadcast();
  }

  function runTestUpdateSystemState() public {
    vm.startBroadcast();
    v3MockOracle.pushPricePercentMovement(1e16); //1%
    updateSystemStateSingleMarket(1);
    vm.stopBroadcast();
  }

  function runTestRedeems() public {
    userRedeem(1, 0, true);
    userRedeem(1, 0, false);
    userRedeem(1, 1, true);
    userRedeem(1, 1, false);
  }
}
*/
