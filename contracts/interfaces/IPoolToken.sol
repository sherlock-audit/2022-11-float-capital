// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../abstract/AccessControlledAndUpgradeable.sol";

import "../interfaces/IMarket.sol";

import "./IMarketExtended.sol";

/**
@title PoolToken
@author float
@notice An ERC20 token that tracks or inversely tracks the price of an
        underlying asset with floating exposure.
*/
interface IPoolToken is IERC20Upgradeable {
  /// @notice Creates an instance of the contract.
  /// @dev Should only be called by TokenFactory.sol for our system.
  /// @param poolInfo info about the token the token is long or short (or other future type) for its market.
  /// @param upgrader Address of contract with permission to upgrade this contract.
  /// @param _marketIndex Which market the token is for.
  /// @param _poolTier Index of the pool
  function initialize(
    IMarketExtended.SinglePoolInitInfo memory poolInfo,
    address upgrader,
    uint32 _marketIndex,
    uint8 _poolTier
  ) external;

  /// @notice Mints a number of pool tokens for an address.
  /// @dev Can only be called by addresses with a minter role.
  /// @param to The address for which to mint the tokens for.
  /// @param amount Amount of pool tokens to mint in wei.
  function mint(address to, uint256 amount) external;

  /// @notice Overrides the default ERC20 transferFrom.
  /// @dev To allow users to avoid approving market contract when redeeming tokens, minter has a virtual infinite allowance.
  /// @param sender User for which to transfer tokens.
  /// @param recipient Recipient of the transferred tokens.
  /// @param amount Amount of tokens to transfer in wei.
  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external returns (bool);

  /// @notice Change ownership of tokens from caller to recipient
  /// @param recipient Receiver of the tokens
  /// @param amount Number of tokens
  function transfer(address recipient, uint256 amount) external returns (bool);

  /// @notice Burns or destroys a number of held pool tokens for an address.
  /// @dev Modified to only allow Market to burn tokens on redeem.
  /// @param amount The amount of tokens to burn in wei.
  function burn(uint256 amount) external;
}
