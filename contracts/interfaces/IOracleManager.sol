// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "../interfaces/chainlink/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/// @title Interface for the Chainlink oracle manager
/// @notice Manages price feeds from Chainlink oracles.
/// @author float
/*
 * Manages price feeds from different oracle implementations.
 */
interface IOracleManager {
  error EmptyArrayOfIndexes();

  error InvalidOracleExecutionRoundId(uint80 oracleRoundId);

  error InvalidOraclePrice(int256 oraclePrice);

  /// @notice Getter function for the state variable chainlinkOracle
  /// @return AggregatorV3Interface for the Chainlink oracle address
  function chainlinkOracle() external view returns (AggregatorV3Interface);

  /// @notice Getter function for the state variable initialEpochStartTimestamp
  /// @return Timestamp of the start of the first ever epoch for the market
  function initialEpochStartTimestamp() external view returns (uint256);

  /// @notice Getter function for the state variable EPOCH_LENGTH
  /// @return Length of the epoch for this market, in seconds
  function EPOCH_LENGTH() external view returns (uint256);

  /// @notice Getter function for the state variable MINIMUM_EXECUTION_WAIT_THRESHOLD
  /// @return Least amount of time needed to wait after epoch end time for the next valid price
  function MINIMUM_EXECUTION_WAIT_THRESHOLD() external view returns (uint256);

  /// @notice Returns index of the current epoch based on block.timestamp
  /// @dev Called by internal functions to get current epoch index
  /// @return getCurrentEpochIndex the current epoch index
  function getCurrentEpochIndex() external view returns (uint256);

  /// @notice Returns start timestamp of current epoch
  /// @return getEpochStartTimestamp start timestamp of the current epoch
  function getEpochStartTimestamp() external view returns (uint256);

  /// @notice Check that the given array of oracle prices are valid for the epochs that need executing
  /// @param _latestExecutedEpochIndex The index of the epoch that was last executed
  /// @param latestExecutedOracleRoundId The roundId of the oracle price associated with the latest executed epoch
  /// @param oracleRoundIdsToExecute Array of roundIds to be validated
  /// @return previousPrice Oracle price associated with the latest executed epoch
  /// @return prices Array of prices to be used for epoch execution
  function validateAndReturnMissedEpochInformation(
    uint32 _latestExecutedEpochIndex,
    uint80 latestExecutedOracleRoundId,
    uint80[] memory oracleRoundIdsToExecute
  ) external view returns (int256 previousPrice, int256[] memory prices);
}
