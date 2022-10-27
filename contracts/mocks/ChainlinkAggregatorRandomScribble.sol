// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interfaces/chainlink/AggregatorV3Interface.sol";
import "../abstract/AccessControlledAndUpgradeable.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

/*
 * ChainlinkAggregatorFaster is a wrapper around the real chainlink aggregator that simulates price updates at a faster rate
 * than the chainlink aggregator. These faster prices are only for testing, and determined in a deterministic way.
 */
contract ChainlinkAggregatorRandomScribble is AggregatorV3Interface, AccessControlledAndUpgradeable {
  uint8 public immutable override decimals;
  uint256 public immutable override version;
  string public constant override description = "A randomized chainlink oracle for scribble testing";
  uint256 public constant MAX_ROUNDS_TO_EXECUTE = 20000;

  uint256 public immutable heartbeat;
  uint256 public immutable oracleDeploymentTime;

  int256[] public prices;

  constructor(
    uint8 _decimals,
    uint256 _version,
    uint256 _heartbeat
  ) {
    heartbeat = _heartbeat;

    decimals = _decimals;
    version = _version;

    oracleDeploymentTime = block.timestamp;

    prices.push(1e18);
  }

  function getCurrentRoundId() public view returns (uint80) {
    return uint80((block.timestamp - oracleDeploymentTime) / heartbeat);
  }

  function getTimestampFromRoundId(uint80 _roundId) internal view returns (uint256) {
    return oracleDeploymentTime + _roundId * heartbeat;
  }

  ////////////////////////////////////
  /////////// MODIFIERS //////////////
  ////////////////////////////////////

  ////////////////////////////////////
  ///// CONTRACT SET-UP //////////////
  ////////////////////////////////////

  function setup(address admin) public initializer {
    _AccessControlledAndUpgradeable_init(admin);

    generatePricesForRounds(1000);
  }

  ////////////////////////////////////
  ///// IMPLEMENTATION ///////////////
  ////////////////////////////////////

  /// @dev Pseudo randomly generates a value between 99e16 and 101e16 from the roundId, can be used to create price 'noise'.
  // slither-disable-next-line weak-prng
  function changePriceUpOrDownByLessThan1Percent(int256 currentPrice, uint80 roundId) public pure returns (int256) {
    return (currentPrice * (1e18 + int256((uint256(keccak256(abi.encode(roundId))) % 2e16)) - 1e16)) / 1e18;
  }

  // NOTE: we could do this on demand in the getRoundData function, but that would mean that function can't be view, and it would break the chainlink interface
  function generatePricesForRounds(uint80 latestRoundIdToUse) public {
    require(latestRoundIdToUse <= MAX_ROUNDS_TO_EXECUTE, "latestRoundIdToUse too large");
    uint256 nextRoundToProcess = prices.length;

    while (nextRoundToProcess <= latestRoundIdToUse) {
      prices.push(changePriceUpOrDownByLessThan1Percent(prices[nextRoundToProcess - 1], uint80(nextRoundToProcess)));
      nextRoundToProcess++;
    }
  }

  function numberOfRounds() public view returns (uint80) {
    return uint80(prices.length);
  }

  function getRoundData(uint80 _roundId)
    public
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
    if (getCurrentRoundId() < _roundId) {
      revert("roundId too high");
    }
    if (prices.length < _roundId) {
      revert("Haven't generated that many prices yet");
    }

    uint256 timestamp = getTimestampFromRoundId(_roundId);
    return (_roundId, prices[_roundId], timestamp, timestamp, _roundId);
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
    return getRoundData(getCurrentRoundId());
  }
}
