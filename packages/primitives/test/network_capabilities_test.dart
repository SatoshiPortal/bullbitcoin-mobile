import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  const historicalBitcoin = {
    NetworkCapability.softwareWallet,
    NetworkCapability.exchange,
    NetworkCapability.swaps,
    NetworkCapability.payjoin,
    NetworkCapability.hardwareWallet,
    NetworkCapability.silentPayments,
    NetworkCapability.publicExplorer,
    NetworkCapability.publicFeeEstimates,
  };
  const historicalLiquid = {
    NetworkCapability.softwareWallet,
    NetworkCapability.exchange,
    NetworkCapability.swaps,
    NetworkCapability.hardwareWallet,
    NetworkCapability.publicExplorer,
    NetworkCapability.publicFeeEstimates,
  };
  const expected = <Network, Set<NetworkCapability>>{
    BitcoinNetwork.mainnet: historicalBitcoin,
    BitcoinNetwork.testnet: historicalBitcoin,
    LiquidNetwork.mainnet: historicalLiquid,
    LiquidNetwork.testnet: historicalLiquid,
    BitcoinNetwork.regtest: {
      NetworkCapability.softwareWallet,
      NetworkCapability.swaps,
    },
    BitcoinNetwork.signet: {},
    LiquidNetwork.regtest: {
      NetworkCapability.softwareWallet,
      NetworkCapability.swaps,
    },
  };

  for (final network in <Network>[
    ...BitcoinNetwork.values,
    ...LiquidNetwork.values,
  ]) {
    test('explicit capability policy for $network', () {
      final allowed = expected[network];
      expect(
        allowed,
        isNotNull,
        reason: 'Every concrete network needs a policy',
      );
      for (final capability in NetworkCapability.values) {
        expect(
          NetworkCapabilities.supports(network, capability),
          allowed?.contains(capability),
          reason: '$network / $capability',
        );
      }
    });
  }
}
