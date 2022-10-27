// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../interfaces/IMarket.sol";
import "../abstract/AccessControlledAndUpgradeable.sol";

/// @notice Manages yield accumulation for the market contract. Each market is deployed with its own yield manager to simplify the bookkeeping, as different markets may share a payment token and yield pool.
interface ILiquidityManager {
  // /// @notice Deposits the given amount of payment tokens into this yield manager.
  // /// @param amount Amount of payment token to deposit
  // function depositPaymentToken(uint256 amount) external;

  /// @notice Allows the market to pay out a user from tokens already withdrawn from Aave
  /// @param user User to recieve the payout
  /// @param amount Amount of payment token to pay to user
  function transferPaymentTokensToUser(address user, uint256 amount) external;
}
