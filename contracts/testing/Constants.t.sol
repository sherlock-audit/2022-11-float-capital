// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "./MarketFactory.t.sol";

contract Constants {
  int256 constant ONE_PERCENT = 1e16;

  uint256 constant DEFAULT_FIXED_EPOCH_LENGTH = 3600;
  uint256 constant DEFAULT_MINIMUM_EXECUTION_WAITING_TIME = 10;

  MarketFactory.MarketContractType constant DEFAULT_MARKET_TYPE = MarketFactory.MarketContractType.MarketTieredLeverageInternalStateSetters;

  address constant ADMIN = address(bytes20(keccak256("ADMIN")));
  // address constant ADMIN_MUMBAI = 0x2740EA9F72B23372621D8D718F52609b80c24E61; // This is an alternate admin address for Mumbai that has been used at times.
  address constant ADMIN_MUMBAI = 0x738edd7F6a625C02030DbFca84885b4De5252903;
  address constant ADMIN_GOERLI = 0x738edd7F6a625C02030DbFca84885b4De5252903;
  address constant ADMIN_FUJI = 0x738edd7F6a625C02030DbFca84885b4De5252903;
  address constant ADMIN_POLYGON = 0x0d8A1efd7438107910c56bE45839c5E0E4346bf6;
  address constant ADMIN_GANACHE = 0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1; // first acc on `ganache --deterministic`

  address constant ALICE = address(bytes20(keccak256("ALICE")));
  address constant BOB = address(bytes20(keccak256("BOB")));

  uint128 constant MAX_UINT128 = type(uint128).max;

  uint8 constant DEFAULT_ORACLE_DECIMALS = 18;
  uint80 constant DEFAULT_ORACLE_FIRST_ROUND_ID = 1;
  int256 constant DEFAULT_ORACLE_FIRST_PRICE = 1e18;
  uint80 constant DEFAULT_ANSWERED_IN_ROUND = 1;

  uint256 constant DEFAULT_START_TIMESTAMP = 1654000000;

  address constant ETH_ORACLE_MUMBAI_ADDRESS = 0x0715A7794a1dc8e42615F059dD6e406A6594651A;
  address constant LINK_ORACLE_MUMBAI_ADDRESS = 0x12162c3E810393dEC01362aBf156D7ecf6159528;
  address constant AVAX_ORACLE_FUJI_ADDRESS = 0x5498BB86BC934c8D34FDA08E81D444153d0D06aD;

  address constant ETH_ORACLE_GOERLI_ADDRESS = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;

  address constant KEEPER_MUMBAI_ADDRESS = 0x537f6Dd8C645FDeb4BBEEb964d9128b1751E3122;
  address constant KEEPER_FUJI_ADDRESS = 0x2d0311dEaF97a135E5a7a4c73bC096C2e300ff96;
  address constant KEEPER_ANVIL_ADDRESS = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9; // Deterministic address that anvil uses for deployments.

  address constant DEFAULT_PAYMENT_TOKEN_MUMBAI_ADDRESS = 0xfFeAB3A650bEbF2Ec8cA71a5574CBb6C51a3C90E;
  address constant DEFAULT_PAYMENT_TOKEN_FUJI_ADDRESS = 0x882f02970F336Cc12ce3f0693fb4a8f887A18550;
  address constant DEFAULT_PAYMENT_TOKEN_ANVIL_ADDRESS = 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707;

  address constant SHIFTER_PROXY_ADDRESS_ANVIL = 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853;
  address constant SHIFTER_PROXY_ADDRESS_FUJI = 0xc7b40c2b1503A9F8d2972ef0D38E3592CB0355dB;
  address constant SHIFTER_PROXY_ADDRESS_MUMBAI = 0xeB27976908d7F5a04D7614Ee8817E4aAEDDAe3D2;

  uint256 constant CHAIN_ID_POLYGON = 137;
  uint256 constant CHAIN_ID_AVALANCHE = 43114;
  uint256 constant CHAIN_ID_MUMBAI = 80001;
  uint256 constant CHAIN_ID_FUJI = 43113;
  uint256 constant CHAIN_ID_GOERLI = 5;
  uint256 constant CHAIN_ID_GANACHE = 1337;
  uint256 constant CHAIN_ID_ANVIL = 31337;
}
