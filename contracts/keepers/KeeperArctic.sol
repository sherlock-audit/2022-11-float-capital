/*
background: This is an experimental, quickly hashed together contract.
It will never hold value of any kind.

The goal is that a future version of this contract becomes a proper keeper contract.

For now no effort has been put into making it conform to the proper keeper interface etc.
*/

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "../abstract/AccessControlledAndUpgradeable.sol";
import "../interfaces/IMarket.sol";
import "../interfaces/IMarketExtended.sol";
import "../interfaces/IOracleManager.sol";
import "../interfaces/IRegistry.sol";
import "../interfaces/chainlink/KeeperCompatibleInterface.sol";

import "./OracleManagerUtils.sol";

// TODO: add 'time delay' capability to the upkeep so that we can run both keepers (gelato, chainlink, and our own) but with different trigger points.
//       https://github.com/Float-Capital/monorepo/issues/3710
contract KeeperArctic is AccessControlledAndUpgradeable, KeeperCompatibleInterface {
  IRegistry public registry;
  uint256 public _stakerDeprecated;

  mapping(uint32 => uint256) public _updateTimeThresholdInSecondsDeprecated;
  mapping(uint32 => uint256) public _percentChangeThresholdDeprecated;
  mapping(uint32 => uint256) public _batchPaymentTokenValueThresholdDeprecated;

  function initialize(address _admin, address _registry) external initializer {
    registry = IRegistry(_registry);

    _AccessControlledAndUpgradeable_init(_admin);
  }

  function setRegistry(address _registry) external onlyRole(ADMIN_ROLE) {
    registry = IRegistry(_registry);
  }

  function performUpkeep(bytes calldata dataForUpkeep) external {
    (IMarketTieredLeverage market, uint80[] memory missedEpochsOracleRoundIds) = abi.decode(dataForUpkeep, (IMarketTieredLeverage, uint80[]));
    market.updateSystemStateUsingValidatedOracleRoundIds(missedEpochsOracleRoundIds);
  }

  // Functian that the keeper calls
  function updateSystemStateForMarket(IMarketTieredLeverage market, uint80[] memory missedEpochsOracleRoundIds) external {
    market.updateSystemStateUsingValidatedOracleRoundIds(missedEpochsOracleRoundIds);
  }

  function shouldUpdateMarketCore()
    public
    view
    returns (
      bool shouldUpdate,
      IMarketTieredLeverage market,
      uint80[] memory missedEpochsOracleRoundIds
    )
  {
    uint256 latestMarket = registry.latestMarket();
    for (uint32 index = 1; index <= latestMarket; index++) {
      market = IMarketTieredLeverage(registry.separateMarketContracts(index));
      IOracleManager oracleManager = market.get_oracleManager();
      IMarketCommon.EpochInfo memory epochInfo = market.get_epochInfo();

      uint80[] memory _missedEpochOracleRoundIds = OracleManagerUtils.getOracleInfoForSystemStateUpdate(
        oracleManager,
        epochInfo.latestExecutedEpochIndex,
        epochInfo.latestExecutedOracleRoundId
      );

      if (_missedEpochOracleRoundIds.length > 0) {
        missedEpochsOracleRoundIds = new uint80[](_missedEpochOracleRoundIds.length);
        for (uint256 i = 0; i < _missedEpochOracleRoundIds.length; i++) {
          missedEpochsOracleRoundIds[i] = _missedEpochOracleRoundIds[i];
        }
        return (true, market, missedEpochsOracleRoundIds);
      }
    }
  }

  function shouldUpdateMarketCallable() external returns (bool canExec, bytes memory execPayload) {
    (bool shouldUpdate, IMarketTieredLeverage market, uint80[] memory missedEpochsOracleRoundIds) = shouldUpdateMarketCore();
    if (shouldUpdate) {
      return (true, abi.encodeCall(this.updateSystemStateForMarket, (market, missedEpochsOracleRoundIds)));
    }
    registry = registry; //prevents warning about view function
    return (false, "");
  }

  function checkUpkeep(bytes calldata) external view returns (bool upkeepNeeded, bytes memory performData) {
    (bool shouldUpdate, IMarketTieredLeverage market, uint80[] memory missedEpochsOracleRoundIds) = shouldUpdateMarketCore();
    if (shouldUpdate) {
      return (true, abi.encode(market, missedEpochsOracleRoundIds));
    }
    return (false, "");
  }

  function shouldUpdateMarket() external view returns (bool canExec, bytes memory execPayload) {
    (bool shouldUpdate, IMarketTieredLeverage market, uint80[] memory missedEpochsOracleRoundIds) = shouldUpdateMarketCore();
    if (shouldUpdate) {
      return (true, abi.encodeCall(this.updateSystemStateForMarket, (market, missedEpochsOracleRoundIds)));
    }
    return (false, "");
  }

  // Test code - only for debugging
  event TestUpdateSystemStateForMarket(address indexed market, uint80[] missedEpochsOracleRoundIds);

  // Functian that the keeper calls
  function updateSystemStateForMarketTest(IMarketTieredLeverage market, uint80[] memory missedEpochsOracleRoundIds) external {
    emit TestUpdateSystemStateForMarket(address(market), missedEpochsOracleRoundIds);
  }

  function shouldUpdateMarketTest() external view returns (bool canExec, bytes memory execPayload) {
    (bool shouldUpdate, IMarketTieredLeverage market, uint80[] memory missedEpochsOracleRoundIds) = shouldUpdateMarketCore();

    if (shouldUpdate) {
      return (true, abi.encodeCall(this.updateSystemStateForMarketTest, (market, missedEpochsOracleRoundIds)));
    }

    return (false, "");
  }

  uint256[100] __testGap;

  uint256 public currentTestUpdate;
  event TestKeeperExecuted(uint256 indexed currentTestUpdddate);

  function updateCurrentTestUpdate(uint256 _currentTestUpdate) external {
    currentTestUpdate = _currentTestUpdate;
    emit TestKeeperExecuted(_currentTestUpdate);
  }

  function gelatoTest() external view returns (bool, bytes memory execPayload) {
    //slither-disable-next-line block-timestamp
    if (currentTestUpdate < block.timestamp / 60) {
      return (true, abi.encodeCall(this.updateCurrentTestUpdate, block.timestamp / 60));
    } else {
      return (false, "");
    }
  }
}
