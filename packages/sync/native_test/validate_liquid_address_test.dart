import 'package:bull_sdk/bull_sdk.dart' show BullSdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/read.dart';
import 'package:sync/sync.dart';

// Liquid address validation through the real LWK binding. Run with the pinned
// bull_sdk host library on LD_LIBRARY_PATH (see README, "Host-native Liquid
// smoke test").
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => BullSdk.init());

  // P2WPKH script with a fixed public test hash; no key material.
  const script = '0014${'0101010101010101010101010101010101010101'}';
  const networks = {
    LiquidNetwork.mainnet: lwk.LiquidNetwork.mainnet,
    LiquidNetwork.testnet: lwk.LiquidNetwork.testnet,
    LiquidNetwork.regtest: lwk.LiquidNetwork.regtest,
  };

  test('a Liquid address is valid only on its own concrete network', () async {
    for (final source in networks.entries) {
      final address = await lwk.Address.addressFromScript(
        network: source.value,
        script: script,
      );
      for (final selected in networks.keys) {
        final result = await validateAddress(address.standard, selected);
        expect(
          result is Ok,
          source.key == selected,
          reason: '${address.standard} from ${source.key} on $selected',
        );
        if (result case Err(:final failure)) {
          expect(failure, isA<TransactionSyncInvalidAddressFailure>());
        }
      }
    }
  });

  test('a regtest address is accepted on Liquid regtest', () async {
    final address = await lwk.Address.addressFromScript(
      network: lwk.LiquidNetwork.regtest,
      script: script,
    );
    expect(address.standard, startsWith('ert1'));
    expect(
      await validateAddress(address.standard, LiquidNetwork.regtest),
      isA<Ok<void, TransactionSyncFailure>>(),
    );
  });

  test('malformed and foreign Liquid addresses fail closed', () async {
    for (final network in networks.keys) {
      for (final address in ['not an address', 'ert1regtest', 'el1regtest']) {
        expect(
          await validateAddress(address, network),
          isA<Err<void, TransactionSyncFailure>>(),
          reason: '$address on $network',
        );
      }
    }
  });
}
