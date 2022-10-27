/* // SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../testing/FloatContractsCoordinator.s.sol";
import "./Shifting.sol";

contract MyScript is FloatContractsCoordinator {
  mapping(address => Shifting) public paymentTokenShifterMapping;

  function run() public {
    setupContractCoordinator();
    vm.startBroadcast();
    keeper = KeeperArctic(getKeeperAddress());

    IRegistry registry = keeper.registry();

    uint32 numberOfMarkets = registry.latestMarket();

    for (uint32 marketIndex = 1; marketIndex <= numberOfMarkets; marketIndex++) {
      MarketExtended market = MarketExtended(address(registry.separateMarketContracts(marketIndex)));

      address marketPaymentToken = market.get_paymentToken();

      if (address(paymentTokenShifterMapping[marketPaymentToken]) == address(0)) {
        address shifterImplementation = address(new Shifting());
        paymentTokenShifterMapping[marketPaymentToken] = Shifting(
          address(
            new ERC1967Proxy(shifterImplementation, abi.encodeCall(Shifting(shifterImplementation).initialize, (msg.sender, marketPaymentToken)))
          )
        );
      }

      // add the market to the correct shifter (for the market's payment token)
      paymentTokenShifterMapping[marketPaymentToken].addValidMarket(address(market));
    }
    vm.stopBroadcast();
  }
}
 */
