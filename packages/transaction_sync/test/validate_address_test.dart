import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/read.dart';
import 'package:transaction_sync/transaction_sync.dart';

void main() {
  test(
    'Bitcoin witness addresses require the selected concrete network',
    () async {
      const cases = {
        BitcoinNetwork.mainnet: bdk.Network.bitcoin,
        BitcoinNetwork.testnet: bdk.Network.testnet,
        BitcoinNetwork.regtest: bdk.Network.regtest,
      };
      final script = bdk.Script(
        rawOutputScript: Uint8List.fromList([0, 20, ...List.filled(20, 1)]),
      );
      try {
        for (final source in cases.entries) {
          final native = bdk.Address.fromScript(
            script: script,
            network: source.value,
          );
          try {
            for (final selected in cases.keys) {
              final result = await validateAddress(native.toString(), selected);
              expect(result is Ok, source.key == selected);
              if (result case Err(:final failure)) {
                expect(failure, isA<TransactionSyncInvalidAddressFailure>());
              }
            }
          } finally {
            native.dispose();
          }
        }
      } finally {
        script.dispose();
      }
    },
  );

  test(
    'legacy testnet remains accepted but cannot authorize regtest',
    () async {
      final script = bdk.Script(
        rawOutputScript: Uint8List.fromList([
          0x76,
          0xa9,
          20,
          ...List.filled(20, 1),
          0x88,
          0xac,
        ]),
      );
      final native = bdk.Address.fromScript(
        script: script,
        network: bdk.Network.testnet,
      );
      try {
        expect(
          await validateAddress(native.toString(), BitcoinNetwork.testnet),
          isA<Ok>(),
        );
        expect(
          await validateAddress(native.toString(), BitcoinNetwork.regtest),
          isA<Err>(),
        );
      } finally {
        native.dispose();
        script.dispose();
      }
    },
  );

  // Liquid validation calls LWK through bull_sdk's native library, which
  // ordinary unit tests do not load: those cases are in
  // native_test/validate_liquid_address_test.dart.
  test('malformed Bitcoin addresses fail closed', () async {
    for (final network in BitcoinNetwork.values) {
      expect(await validateAddress('not an address', network), isA<Err>());
    }
  });
}
