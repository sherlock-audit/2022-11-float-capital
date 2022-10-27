// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interfaces/chainlink/AggregatorV3Interface.sol";
import "../abstract/AccessControlledAndUpgradeable.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

/*
 * ChainlinkAggregatorFaster is a wrapper around the real chainlink aggregator that simulates price updates at a faster rate
 * than the chainlink aggregator. These faster prices are useful on testnet when we want chainlink to update faster, and
 * do it in a deterministic way.
 */
contract ChainlinkAggregatorFaster is AggregatorV3Interface, AccessControlledAndUpgradeable {
  // Admin contracts.
  AggregatorV3Interface public immutable baseChainlinkAggregator;
  uint8 public immutable override decimals;
  uint256 public immutable override version;
  string public constant override description = "A wrapper around a chainlink oracel to help simulate faster oracle updates";

  /// @dev - if this value is updating once an hour on average (every 60 minutes), then a speedup factor of 60 would make the oracle update every minute on average.
  uint256 public immutable speedupFactor;
  // @dev - the number of seconds that the fast update will take.
  uint256 public immutable fastOracleUpdateLength;

  int256 offset;

  struct RoundData {
    uint80 answeredInRound;
    int256 answer;
    uint256 setAt;
  }
  mapping(uint80 => RoundData) public roundData;

  constructor(
    AggregatorV3Interface _baseChainlinkAggregator,
    uint256 _speedupFactor,
    uint256 _fastOracleUpdateLength
  ) {
    baseChainlinkAggregator = _baseChainlinkAggregator;
    speedupFactor = _speedupFactor;
    fastOracleUpdateLength = _fastOracleUpdateLength;

    decimals = _baseChainlinkAggregator.decimals();
    version = _baseChainlinkAggregator.version();
  }

  ////////////////////////////////////
  /////////// MODIFIERS //////////////
  ////////////////////////////////////

  ////////////////////////////////////
  ///// CONTRACT SET-UP //////////////
  ////////////////////////////////////

  function setup(address admin) public initializer {
    _AccessControlledAndUpgradeable_init(admin);
  }

  ////////////////////////////////////
  ///// IMPLEMENTATION ///////////////
  ////////////////////////////////////

  /// @dev Pseudo randomly generates a value between 99e16 and 101e16 from the roundId, can be used to create price 'noise'.
  // slither-disable-next-line weak-prng
  function changePriceUpOrDownByLessThan1Percent(int256 currentPrice, uint80 roundId) public pure returns (int256) {
    return (currentPrice * (1e18 + int256((uint256(keccak256(abi.encode(roundId))) % 2e16)) - 1e16)) / 1e18;
  }

  function determinePredictedUpdatedAtTime(uint256 chainlinkOracleSubIndex, uint256 updatedAtSource) internal view returns (uint256 updatedAt) {
    updatedAt = updatedAtSource + Math.min((chainlinkOracleSubIndex * fastOracleUpdateLength), (speedupFactor - 1) * fastOracleUpdateLength);
  }

  function getRoundDataFromChainlinkData(
    uint256 chainlinkOracleSubIndex,
    uint80 roundIdSource,
    int256 answerSource,
    uint256 updatedAtSource,
    uint80 _answeredInRoundSource
  )
    public
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    if (chainlinkOracleSubIndex > speedupFactor || chainlinkOracleSubIndex == 0) {
      return (roundIdSource * uint80(speedupFactor), answerSource, updatedAtSource, updatedAtSource, _answeredInRoundSource);
    } else {
      updatedAt = determinePredictedUpdatedAtTime(chainlinkOracleSubIndex, updatedAtSource);
      startedAt = updatedAt; // always keep these equal in the simulation.

      roundId = (roundIdSource * uint80(speedupFactor)) + uint80(chainlinkOracleSubIndex);

      // Randomly deviates within +/-1% of the answer.
      answer = changePriceUpOrDownByLessThan1Percent(answerSource, roundId);

      return (roundId, answer, startedAt, updatedAt, 1);
    }
  }

  function getRoundData(uint80 _roundId)
    external
    view
    override
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    (uint80 roundIdImplementation, , , , ) = baseChainlinkAggregator.latestRoundData();

    uint80 chainLinkOriginalId = _roundId / uint80(speedupFactor);

    if (chainLinkOriginalId > roundIdImplementation) {
      revert("RoundId too high");
    }

    (uint80 roundIdSource, int256 answerSource, , uint256 updatedAtSource, uint80 _answeredInRoundSource) = baseChainlinkAggregator.getRoundData(
      chainLinkOriginalId
    );

    if (chainLinkOriginalId < roundIdImplementation) {
      (, , , uint256 updatedAtNext, ) = baseChainlinkAggregator.getRoundData(chainLinkOriginalId + 1);
      updatedAt = determinePredictedUpdatedAtTime(uint256(_roundId) % (speedupFactor), updatedAtSource);

      if (updatedAt >= updatedAtNext) {
        (, int256 answerNext, uint256 startedAtNext, , uint80 _answeredInRoundNext) = baseChainlinkAggregator.getRoundData(chainLinkOriginalId + 1);

        return (_roundId, answerNext, startedAtNext, updatedAtNext, _answeredInRoundNext);
      }
    }

    return getRoundDataFromChainlinkData(_roundId % uint80(speedupFactor), roundIdSource, answerSource, updatedAtSource, _answeredInRoundSource);
  }

  function latestRoundData()
    external
    view
    override
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    (uint80 roundIdSource, int256 answerSource, , uint256 updatedAtSource, uint80 _answeredInRoundSource) = baseChainlinkAggregator.latestRoundData();

    return
      getRoundDataFromChainlinkData(
        (block.timestamp - updatedAtSource) / fastOracleUpdateLength,
        roundIdSource,
        answerSource,
        updatedAtSource,
        _answeredInRoundSource
      );
  }
}
