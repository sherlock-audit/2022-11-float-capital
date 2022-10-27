// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../../abstract/AccessControlledAndUpgradeable.sol";
import "../../abstract/ProxyNonPayable.sol";
import "../../interfaces/IMarket.sol";
import "../../interfaces/IOracleManager.sol";
import "../../interfaces/IRegistry.sol";
import "../../interfaces/ILiquidityManager.sol";
import "../../market/template/MarketStorage.sol";
import "../../interfaces/IMarket.sol";

import "./MarketTieredLeverageForInternalMocking.t.sol";
import "../MarketTieredLeverageInternalStateSetters.sol";

contract MarketTieredLeverageMockable is MarketTieredLeverageInternalStateSetters {
  MarketTieredLeverageForInternalMocking mocker;
  bool shouldUseMock;
  string functionToNotMock;

  constructor(
    IMarketExtended _nonCoreFunctionsDelegatee,
    address _paymentToken,
    IRegistry _registry
  ) MarketTieredLeverageInternalStateSetters(_nonCoreFunctionsDelegatee, _paymentToken, _registry) {}

  function setMocker(MarketTieredLeverageForInternalMocking _mocker) external {
    mocker = _mocker;
  }

  function disableMocker() external {
    shouldUseMock = false;
  }

  function setFunctionToNotMock(string calldata _functionToNotMock) external {
    functionToNotMock = _functionToNotMock;
    shouldUseMock = true;
  }
}
