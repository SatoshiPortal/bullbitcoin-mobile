import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

// Hostile input through the real LWK parser. Run with the pinned bull_sdk host
// library on LD_LIBRARY_PATH (see README, "Native test suites").
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => BullSdk.init());

  // A Bitcoin transaction: valid consensus bytes, but not an Elements one.
  final bitcoin =
      '0100000001${'00' * 32}ffffffff020101ffffffff01a0860100000000000151'
      '00000000';

  List<int> bytes(String hex) => [
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ];

  for (final (name, input) in [
    ('a Bitcoin transaction', bytes(bitcoin)),
    ('a truncated transaction', bytes(bitcoin.substring(0, 40))),
    ('random bytes', List.generate(256, (i) => i * 31 % 256)),
  ]) {
    test('decodeLiquidTransaction refuses $name', () {
      expect(
        decodeLiquidTransaction(input),
        isA<Err<DecodedLiquidTransaction, SyncFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<SyncInvalidTransactionFailure>(),
        ),
      );
    });
  }

  for (final (name, input) in [
    ('text', 'not a pset'),
    ('a Bitcoin PSBT', 'cHNidP8BAAoCAAAAAAAAAAAAAA=='),
    ('a truncated PSET', 'cHNldP8BAgQCAAAA'),
  ]) {
    test('decodeLiquidPset refuses $name', () {
      expect(
        decodeLiquidPset(input),
        isA<Err<DecodedLiquidTransaction, SyncFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<SyncInvalidTransactionFailure>(),
        ),
      );
    });
  }
}
