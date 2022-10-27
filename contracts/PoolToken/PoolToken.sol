// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "../interfaces/IPoolToken.sol";

/**
@title PoolToken
@notice An ERC20 token representing one's share in a pool of collateral.
@dev Logic for how collateral is moved between pools contained in Market contracts
     The contract inherits from ERC20PresetMinterPauser.sol
*/
contract PoolToken is AccessControlledAndUpgradeable, ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PermitUpgradeable, IPoolToken {
  /// @notice Role that is assigned to the single entity that is allowed to call mint
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  /// @notice Address of the market contract, a deployed market.sol
  address public immutable market;

  /// @notice Identifies which market in minter the token is for.
  uint32 public marketIndex;
  /// @notice Whether the token is a long, short or float token for its market.
  /// @dev A future version of the protocol could explore making the poolType and poolTier variables immutable to save gas on token transfers.
  IMarketCommon.PoolType public immutable poolType;
  /// @notice The index of the pool on a particular side (long or short) of the market
  uint8 public immutable poolTier;

  /// Upgradability - implementation constructor:
  constructor(
    address _market,
    IMarketCommon.PoolType _poolType,
    uint8 _poolTier
  ) initializer {
    require(_market != address(0));
    market = _market;

    poolType = _poolType;
    poolTier = _poolTier;
  }

  /// @notice Creates an instance of the contract.
  /// @param poolInfo info about the token the token is long or short (or other future type) for its market.
  /// @param upgrader Address of contract with permission to upgrade this contract.
  /// @param _marketIndex Which market the token is for.
  function initialize(
    IMarketExtended.SinglePoolInitInfo memory poolInfo,
    address upgrader,
    uint32 _marketIndex,
    uint8 _poolTier
  ) external initializer {
    require(msg.sender == market);
    assert(poolInfo.token == address(this));
    _AccessControlledAndUpgradeable_init(upgrader);
    __ERC20_init(poolInfo.name, poolInfo.symbol);
    __ERC20Burnable_init();
    __ERC20Permit_init(poolInfo.name);

    _setupRole(MINTER_ROLE, market);

    marketIndex = _marketIndex;
    //slither-disable-next-line missing-events-arithmetic
    require(poolType == poolInfo.poolType && poolTier == _poolTier, "misconfigured token");
  }

  /*╔══════════════════════════════════════════════════════╗
    ║    FUNCTIONS INHERITED BY ERC20PresetMinterPauser    ║
    ╚══════════════════════════════════════════════════════╝*/

  /// @notice Returns the number of tokens in circulation
  /// @return Number of tokens in circulation
  function totalSupply() public view override(ERC20Upgradeable, IERC20Upgradeable) returns (uint256) {
    return ERC20Upgradeable.totalSupply();
  }

  /**
  @notice Mints a number of pool tokens for an address.
  @dev Can only be called by addresses with a minter role.
        This should correspond to the Market contract.
  @param to The address for which to mint the tokens for.
  @param amount Amount of pool tokens to mint in wei.
  */
  function mint(address to, uint256 amount) external override onlyRole(MINTER_ROLE) {
    _mint(to, amount);
  }

  /// @notice Burns or destroys a number of held pool tokens for an address.
  /// @dev Modified to only allow Market to burn tokens on redeem.
  /// @param amount The amount of tokens to burn in wei.
  function burn(uint256 amount) public override(ERC20BurnableUpgradeable, IPoolToken) onlyRole(MINTER_ROLE) {
    super._burn(_msgSender(), amount);
  }

  /**
  @notice Overrides the default ERC20 transferFrom.
  @dev To allow users to avoid approving market contract when redeeming tokens,
       minter has a virtual infinite allowance.
  @param sender User for which to transfer tokens.
  @param recipient Recipient of the transferred tokens.
  @param amount Amount of tokens to transfer in wei.
  */
  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public override(ERC20Upgradeable, IPoolToken) returns (bool) {
    if (recipient == market && msg.sender == market) {
      // If it to minter and msg.sender is minter don't perform additional transfer checks.
      ERC20Upgradeable._transfer(sender, recipient, amount);
      return true;
    }

    return ERC20Upgradeable.transferFrom(sender, recipient, amount);
  }

  /**
  @param recipient Receiver of the tokens
  @param amount Number of tokens
  */
  function transfer(address recipient, uint256 amount) public override(ERC20Upgradeable, IPoolToken) returns (bool) {
    return ERC20Upgradeable.transfer(recipient, amount);
  }

  /**
  @notice Overrides the OpenZeppelin _beforeTokenTransfer hook
  @dev Ensures that this contract's accounting reflects all the senders's outstanding
       tokens from previous epoch actions (that have been executed) before any token transfer occurs.
       Removal of pausing functionality of ERC20PresetMinterPausable is intentional.
  @param sender User for which tokens are to be transferred for.
  @param to Receiver of the tokens
  @param amount Number of tokens
  */
  function _beforeTokenTransfer(
    address sender,
    address to,
    uint256 amount
  ) internal override {
    if (sender != market && sender != address(0)) {
      IMarket(market).settlePoolUserMints(sender, poolType, poolTier);
    }
    super._beforeTokenTransfer(sender, to, amount);
  }

  /**
  @notice Gets the pool token balance of the user in wei.
  @dev To automatically account for order executions from previous epochs which have been confirmed but not settled,
        includes any outstanding tokens owed by minter.
  @param account The address for which to get the balance of.
  @return balance for the specified account
  */
  function balanceOf(address account) public view override(ERC20Upgradeable, IERC20Upgradeable) returns (uint256) {
    return ERC20Upgradeable.balanceOf(account) + IMarketView(market).getUsersConfirmedButNotSettledPoolTokenBalance(account, poolType, poolTier);
  }
}
