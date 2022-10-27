// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

/// @title Registry interface
/// @author float
/// @notice High-level information about all Float markets
interface IRegistry {
  /// @notice Emitted when the registry contract is initialized
  event RegistryArctic(address admin);

  /// @notice Emitted when a new market is successfully launched
  event SeparateMarketCreated(string name, string symbol, address market, uint32 marketIndex);

  /// @notice Getter function for the separateMarketContracts state variable
  /// @param marketIndex Launch ordinal of the market
  /// @return The address of the market contract
  function separateMarketContracts(uint32 marketIndex) external view returns (address);

  /// @notice Getter function for the latestMarket state variable
  /// @return The index of the latest market added to the registry
  function latestMarket() external view returns (uint32);

  /// @notice Getter function for the gems state variable
  /// @return The address of the gems contract
  function gems() external view returns (address);
}
