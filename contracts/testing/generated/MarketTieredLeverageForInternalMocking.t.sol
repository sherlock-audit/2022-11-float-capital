// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../MarketTieredLeverageInternalStateSetters.sol";

import {Vm} from "forge-std/Vm.sol";

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

contract MarketTieredLeverageForInternalMocking {}
