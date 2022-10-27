// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "../interfaces/IOracleManager.sol";
import "../mocks/AggregatorV3Mock.t.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract RandomnessHelper is Test {
  uint256 randomSeed = 9;

  function randomNumber() public returns (uint256) {
    randomSeed = uint256(keccak256(abi.encode(randomSeed)));
    return randomSeed;
  }

  function randomNumber32() public returns (uint32) {
    randomSeed = uint32(uint256(keccak256(abi.encode(randomSeed))));
    return uint32(randomSeed);
  }

  function randomNumber(uint256 max) public returns (uint256) {
    randomSeed = uint256(keccak256(abi.encode(randomSeed)));
    return randomSeed % Math.max(1, max);
  }

  function randomInRange(uint256 min, uint256 max) public returns (uint256) {
    require(min < max, "min >= max");
    randomSeed = uint256(uint256(keccak256(abi.encode(randomSeed))));
    return min + uint256(randomSeed % (max - min));
  }

  function randomInRange112(uint112 min, uint112 max) public returns (uint112) {
    require(min < max, "min >= max");
    randomSeed = uint112(uint256(keccak256(abi.encode(randomSeed))));
    return min + uint112(randomSeed % (max - min));
  }

  function randomBool() public returns (bool) {
    randomSeed = uint256(keccak256(abi.encode(randomSeed)));
    return randomSeed % 2 == 1;
  }

  function randomAddres() public returns (address) {
    bytes32 hash = keccak256(abi.encode(randomSeed));
    randomSeed = uint256(hash);
    return address(bytes20(hash));
  }

  struct TestOracleInfo {
    uint256 timestamp;
    int256 price;
    uint80 oracleRoundId;
  }

  function amountTimeBetweenOracleUpdate(uint256 seed, IOracleManager oracleManager) internal view returns (uint256 time) {
    // slither-disable-next-line weak-prng
    time = (seed) % oracleManager.EPOCH_LENGTH();
  }

  function generateRandomOracleUpdatesAndGetEpochToExecuteInformation(
    IOracleManager oracleManager,
    AggregatorV3Mock chainlinkOracleMock,
    uint256 maxNumberOfOracleUpdates
  )
    public
    returns (
      uint256 startEpoch,
      TestOracleInfo[] memory epochExecutions,
      uint256 numberOfEpochsToExecute
    )
  {
    randomSeed = uint256(keccak256(abi.encode(randomSeed)));

    epochExecutions = new TestOracleInfo[](maxNumberOfOracleUpdates);

    startEpoch = oracleManager.getCurrentEpochIndex();

    uint256 additionalTime;
    for (uint256 index = 1; index < maxNumberOfOracleUpdates; index++) {
      int256 price = int256(index);
      additionalTime = amountTimeBetweenOracleUpdate(block.timestamp + additionalTime + randomSeed + index, oracleManager);
      vm.warp(block.timestamp + additionalTime);
      chainlinkOracleMock.pushPrice(price);
      uint80 currentOracleUpdateIndex = chainlinkOracleMock.currentRoundId();

      // numberOfEpochsToExecute is unassigned so will start from 0 and + 1 is required because
      // we can only use prices in epoch n + 1 to execute epoch n.
      bool willOraclePriceTriggerEpochExecution = ((startEpoch + numberOfEpochsToExecute + 1) * oracleManager.EPOCH_LENGTH()) +
        // TODO not sure if this logic is still correct
        oracleManager.initialEpochStartTimestamp() +
        oracleManager.MINIMUM_EXECUTION_WAIT_THRESHOLD() <=
        block.timestamp;

      if (willOraclePriceTriggerEpochExecution) {
        // push oracle info to array
        epochExecutions[numberOfEpochsToExecute] = TestOracleInfo(block.timestamp, price, currentOracleUpdateIndex);
        numberOfEpochsToExecute++;
      }
    }
  }
}
