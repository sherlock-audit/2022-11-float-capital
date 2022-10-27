// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../abstract/AccessControlledAndUpgradeable.sol";
import "../interfaces/IPoolToken.sol";
import "../interfaces/IRegistry.sol";
import "../interfaces/IMarket.sol";
import "../util/Math.sol";

// Logic:
// Users call shift function with amount of pool token to shift from a market and target market.
// The contract immediately takes receipt of these tokens and intiates a redeem with the tokens.
// Once the next epoch for that market ends, the keeper will take receipt of the dai and immediately,
// Mint a position with all the dai received in the new market on the users behalf.
// We create a mintFor function on float that allows you to mint a position on another users behalf
// Think about shifts from the same market in consecutive epochs and how this should work

/** @title Shifting Contract */
contract Shifting is AccessControlledAndUpgradeable {
  using MathUintFloat for uint256;

  address public paymentToken;
  uint256 public constant SHIFT_ORDER_MAX_BATCH_SIZE = 20;

  // TODO: determine if this event is needed by the graph. Might be fine to save gas and infer that it is a shift action by patterns, or to omit parts of the event.
  event ShiftActionCreated(
    uint112 amountOfPoolToken,
    address indexed marketFrom,
    uint8 poolTypeFrom,
    address indexed marketTo,
    uint8 poolTypeTo,
    uint32 correspondingEpoch,
    address indexed user
  );

  struct ShiftAction {
    uint112 amountOfPoolToken;
    address marketFrom;
    IMarketCommon.PoolType poolTypeFrom;
    uint8 poolTierFrom;
    address marketTo;
    IMarketCommon.PoolType poolTypeTo;
    uint8 poolTierTo;
    uint32 correspondingEpoch;
    address user;
    bool isExecuted;
  }

  // address of market -> chronilogical list of shift orders
  mapping(address => mapping(uint256 => ShiftAction)) public shiftOrdersForMarket;
  mapping(address => uint256) public latestIndexForShiftAction;
  mapping(address => uint256) public latestExecutedShiftOrderIndex;

  mapping(address => bool) public validMarket;
  address[] public validMarketArray;

  function initialize(address _admin, address _paymentToken) external initializer {
    _AccessControlledAndUpgradeable_init(_admin);
    require(_paymentToken != address(0));
    paymentToken = _paymentToken;
  }

  /// @notice - this assumes that we will never have more than 16 tier types, and 16 tiers of a given tier type.
  // TODO: find a way to re-use the same function from the Market contract (less code duplication)
  function packPoolId(IMarketCommon.PoolType poolType, uint8 poolTier) internal pure virtual returns (uint8) {
    return (uint8(poolType) << 4) | poolTier;
  }

  function addValidMarket(address _market) external onlyRole(ADMIN_ROLE) {
    require(!validMarket[_market], "Market already valid");
    require(paymentToken == IMarket(_market).get_paymentToken(), "Require same payment token");
    validMarket[_market] = true;
    validMarketArray.push(_market);
    require(IERC20(paymentToken).approve(_market, type(uint256).max), "aprove failed");
  }

  function removeValidMarket(address _market) external onlyRole(ADMIN_ROLE) {
    require(validMarket[_market], "Market not valid");
    require(latestExecutedShiftOrderIndex[_market] == latestIndexForShiftAction[_market], "require no pendings shifts"); // This condition can be DDOS.

    validMarket[_market] = false;
    // TODO implement delete from the validMarketArray
  }

  function _getPoolTokenPrice(
    address market,
    IMarketCommon.PoolType poolType,
    uint256 poolIndex
  ) internal view returns (uint256) {
    uint32 currentExecutedEpoch = IMarket(market).get_epochInfo().latestExecutedEpochIndex;

    uint256 price = IMarket(market).get_poolToken_priceSnapshot(currentExecutedEpoch, poolType, poolIndex);

    return price;
  }

  function _getAmountInPaymentToken(
    address _marketFrom,
    IMarketCommon.PoolType poolType,
    uint256 poolIndex,
    uint112 amountPoolToken
  ) internal view returns (uint112) {
    uint256 poolTokenPriceInPaymentTokens = uint256(_getPoolTokenPrice(_marketFrom, poolType, poolIndex));
    return uint112((uint256(amountPoolToken) * poolTokenPriceInPaymentTokens) / 1e18);
  }

  function _validateShiftOrder(
    uint112 _amountOfPoolToken,
    address _marketFrom,
    IMarketCommon.PoolType _poolTypeFrom,
    uint8 _poolTierFrom,
    address _marketTo,
    IMarketCommon.PoolType _poolTypeTo,
    uint8 _poolTierTo
  ) internal view {
    require(validMarket[_marketFrom], "invalid from market");
    require(validMarket[_marketTo], "invalid to market");
    require(_poolTypeFrom == IMarketCommon.PoolType.LONG || _poolTypeFrom == IMarketCommon.PoolType.SHORT, "Bad pool type from");
    require(_poolTypeTo == IMarketCommon.PoolType.LONG || _poolTypeTo == IMarketCommon.PoolType.SHORT, "Bad pool type to");

    // NOTE: this transaction will fail if the from token is non-existent later in the function. No need to check here.
    address tokenTo = IMarket(_marketTo).get_pool_token(_poolTypeTo, _poolTierTo);

    require(tokenTo != address(0), "to pool does not exist");

    require(_getAmountInPaymentToken(_marketFrom, _poolTypeFrom, _poolTierFrom, _amountOfPoolToken) >= 10e18, "invalid shift amount"); // requires at least 10e18 worth of DAI to shift the position.
    // This is important as position may still gain or lose value on current value
    // until the redeem is final. If this is the case the 1e18 mint limit on the market could
    // be violated bruicking the shifter if not careful.
  }

  function shiftOrder(
    uint112 _amountOfPoolToken,
    address _marketFrom,
    IMarketCommon.PoolType _poolTypeFrom,
    uint8 _poolTierFrom,
    address _marketTo,
    IMarketCommon.PoolType _poolTypeTo,
    uint8 _poolTierTo
  ) external {
    // Note add fees

    _validateShiftOrder(_amountOfPoolToken, _marketFrom, _poolTypeFrom, _poolTierFrom, _marketTo, _poolTypeTo, _poolTierTo);

    // User sends tokens to this contract. Will require approval or signature.
    address token = IMarket(address(_marketFrom)).getPoolTokenAddress(_poolTypeFrom, _poolTierFrom);

    //slither-disable-next-line unchecked-transfer
    IPoolToken(token).transferFrom(msg.sender, address(this), _amountOfPoolToken);

    // Redeem needs to execute upkeep otherwise stale epoch for order may be used
    if (_poolTypeFrom == IMarketCommon.PoolType.LONG) {
      IMarket(_marketFrom).redeemLong(_poolTierFrom, _amountOfPoolToken);
    } else if (_poolTypeFrom == IMarketCommon.PoolType.SHORT) {
      IMarket(_marketFrom).redeemShort(_poolTierFrom, _amountOfPoolToken);
    }

    uint32 currentEpochIndex = uint32(IMarket(_marketFrom).get_oracleManager().getCurrentEpochIndex());

    uint256 newLatestIndexForShiftAction = latestIndexForShiftAction[_marketFrom] + 1;
    latestIndexForShiftAction[_marketFrom] = newLatestIndexForShiftAction;

    shiftOrdersForMarket[_marketFrom][newLatestIndexForShiftAction] = ShiftAction({
      amountOfPoolToken: _amountOfPoolToken,
      marketFrom: _marketFrom,
      poolTypeFrom: _poolTypeFrom,
      poolTierFrom: _poolTierFrom,
      marketTo: _marketTo,
      poolTypeTo: _poolTypeTo,
      poolTierTo: _poolTierTo,
      correspondingEpoch: currentEpochIndex, // pull current epoch from the market (upkeep must happen first)
      user: msg.sender,
      isExecuted: false
    });

    emit ShiftActionCreated(
      _amountOfPoolToken,
      _marketFrom,
      packPoolId(_poolTypeFrom, _poolTierFrom),
      _marketTo,
      packPoolId(_poolTypeTo, _poolTierTo),
      currentEpochIndex,
      msg.sender
    );
  }

  function _shouldExecuteShiftOrder()
    internal
    view
    returns (
      bool canExec,
      address market,
      uint256 executeUpUntilAndIncludingThisIndex
    )
  {
    for (uint32 index = 0; index < validMarketArray.length; index++) {
      market = validMarketArray[index];
      uint256 _latestExecutedShiftOrderIndex = latestExecutedShiftOrderIndex[market];
      uint256 _latestIndexForShiftAction = latestIndexForShiftAction[market];

      if (_latestExecutedShiftOrderIndex == _latestIndexForShiftAction) {
        continue; // skip to next market, no outstanding orders to check.
      }

      uint32 latestExecutedEpochIndex = IMarket(market).get_epochInfo().latestExecutedEpochIndex;

      executeUpUntilAndIncludingThisIndex = _latestExecutedShiftOrderIndex;
      uint256 orderDepthToSearch = Math.min(_latestIndexForShiftAction, _latestExecutedShiftOrderIndex + SHIFT_ORDER_MAX_BATCH_SIZE);
      for (uint256 batchIndex = _latestExecutedShiftOrderIndex + 1; batchIndex <= orderDepthToSearch; batchIndex++) {
        // stop if more than 10.
        ShiftAction memory _shiftOrder = shiftOrdersForMarket[market][batchIndex];
        if (_shiftOrder.correspondingEpoch <= latestExecutedEpochIndex) {
          executeUpUntilAndIncludingThisIndex++;
        } else {
          break; // exit loop, no orders after will satisfy this condition.
        }
      }
      if (executeUpUntilAndIncludingThisIndex > _latestExecutedShiftOrderIndex) {
        return (true, market, executeUpUntilAndIncludingThisIndex);
      }
    }
    return (false, address(0), 0);
  }

  function shouldExecuteShiftOrder() external view returns (bool _canExec, bytes memory execPayload) {
    (bool canExec, address market, uint256 executeUpUntilAndIncludingThisIndex) = _shouldExecuteShiftOrder();

    return (canExec, abi.encodeCall(this.executeShiftOrder, (market, executeUpUntilAndIncludingThisIndex)));
  }

  function checkUpkeep(bytes calldata) external view returns (bool upkeepNeeded, bytes memory performData) {
    (bool canExec, address market, uint256 executeUpUntilAndIncludingThisIndex) = _shouldExecuteShiftOrder();

    return (canExec, abi.encode(market, executeUpUntilAndIncludingThisIndex));
  }

  function _executeShiftOrder(address _marketFrom, uint256 _executeUpUntilAndIncludingThisIndex) internal {
    // First claim all oustanding DAI.

    uint256 indexOfNextShiftToExecute = latestExecutedShiftOrderIndex[_marketFrom] + 1;
    require(_executeUpUntilAndIncludingThisIndex >= indexOfNextShiftToExecute, "Cannot execute past");

    for (uint256 _indexOfShift = indexOfNextShiftToExecute; _indexOfShift <= _executeUpUntilAndIncludingThisIndex; _indexOfShift++) {
      ShiftAction memory _shiftOrder = shiftOrdersForMarket[_marketFrom][_indexOfShift];

      // TODO: this code is inefficient if we end up settling the same pool multiple times.
      //       we should pass in an array of the pools we want to settle to keep this lean.
      // https://github.com/Float-Capital/monorepo/issues/3462#issuecomment-1266872958
      IMarket(_marketFrom).settlePoolUserRedeems(address(this), _shiftOrder.poolTypeFrom, _shiftOrder.poolTierFrom);

      require(!_shiftOrder.isExecuted, "Shift already executed"); //  Redundant but wise to have
      shiftOrdersForMarket[_marketFrom][_indexOfShift].isExecuted = true;

      // Calculate the collateral amount to be used for the new mint.
      uint256 poolToken_price = IMarket(_shiftOrder.marketFrom).get_poolToken_priceSnapshot(
        _shiftOrder.correspondingEpoch,
        _shiftOrder.poolTypeFrom,
        _shiftOrder.poolTierFrom
      );
      assert(poolToken_price != 0); // should in theory enforce that the latestExecutedEpoch on the market is >= _shiftOrderEpoch.
      uint256 amountPaymentTokenToMint = uint256(_shiftOrder.amountOfPoolToken).mul(poolToken_price); // could save gas and do this calc here.

      if (_shiftOrder.poolTypeTo == IMarketCommon.PoolType.LONG) {
        IMarket(_shiftOrder.marketTo).mintLongFor(_shiftOrder.poolTierTo, uint112(amountPaymentTokenToMint), _shiftOrder.user);
      } else if (_shiftOrder.poolTypeTo == IMarketCommon.PoolType.SHORT) {
        IMarket(_shiftOrder.marketTo).mintShortFor(_shiftOrder.poolTierTo, uint112(amountPaymentTokenToMint), _shiftOrder.user);
      }
    }

    latestExecutedShiftOrderIndex[_marketFrom] = _executeUpUntilAndIncludingThisIndex;
  }

  function executeShiftOrder(address _marketFrom, uint256 _executeUpUntilAndIncludingThisIndex) external {
    _executeShiftOrder(_marketFrom, _executeUpUntilAndIncludingThisIndex);
  }

  function performUpkeep(bytes calldata dataForUpkeep) external {
    (address marketFrom, uint256 executeUpUntilAndIncludingThisIndex) = abi.decode(dataForUpkeep, (address, uint256));

    _executeShiftOrder(marketFrom, executeUpUntilAndIncludingThisIndex);
  }
}

contract ShiftingProxy is AccessControlledAndUpgradeableModifiers {
  Shifting public currentShifter;

  event ChangeShifter(Shifting newShifter);

  function initialize(Shifting _currentShifter) external initializer {
    _AccessControlledAndUpgradeable_init(msg.sender);

    currentShifter = _currentShifter;
    emit ChangeShifter(_currentShifter);
  }

  function changeShifter(Shifting _currentShifter) external adminOnly {
    currentShifter = _currentShifter;
    emit ChangeShifter(_currentShifter);
  }

  function shouldExecuteShiftOrder() external view returns (bool _canExec, bytes memory execPayload) {
    return currentShifter.shouldExecuteShiftOrder();
  }

  function checkUpkeep(bytes calldata data) external view returns (bool upkeepNeeded, bytes memory performData) {
    return currentShifter.checkUpkeep(data);
  }

  function executeShiftOrder(address _marketFrom, uint256 _executeUpUntilAndIncludingThisIndex) external {
    currentShifter.executeShiftOrder(_marketFrom, _executeUpUntilAndIncludingThisIndex);
  }

  function performUpkeep(bytes calldata dataForUpkeep) external {
    currentShifter.performUpkeep(dataForUpkeep);
  }
}
