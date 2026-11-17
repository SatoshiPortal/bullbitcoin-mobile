import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  test('Bitcoin regtest permits swaps', () {
    expect(
      NetworkCapabilities.supports(
        BitcoinNetwork.regtest,
        NetworkCapability.swaps,
      ),
      isTrue,
    );
  });

  test('Liquid regtest permits swaps', () {
    expect(
      NetworkCapabilities.supports(
        LiquidNetwork.regtest,
        NetworkCapability.swaps,
      ),
      isTrue,
    );
  });

  test('the swap extension keeps unrelated regtest capabilities denied', () {
    for (final network in <Network>[
      BitcoinNetwork.regtest,
      LiquidNetwork.regtest,
    ]) {
      for (final capability in [
        NetworkCapability.exchange,
        NetworkCapability.publicExplorer,
        NetworkCapability.publicFeeEstimates,
        NetworkCapability.hardwareWallet,
      ]) {
        expect(NetworkCapabilities.supports(network, capability), isFalse);
      }
    }
    expect(
      NetworkCapabilities.supports(
        BitcoinNetwork.signet,
        NetworkCapability.swaps,
      ),
      isFalse,
    );
    for (final network in <Network>[
      BitcoinNetwork.mainnet,
      BitcoinNetwork.testnet,
      LiquidNetwork.mainnet,
      LiquidNetwork.testnet,
    ]) {
      expect(
        NetworkCapabilities.supports(network, NetworkCapability.swaps),
        isTrue,
      );
    }
  });
}
