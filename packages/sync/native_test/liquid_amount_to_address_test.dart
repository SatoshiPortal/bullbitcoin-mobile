import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bull_sdk/bull_sdk.dart' show BullSdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/src/data/codec/liquid_codec.dart';
import 'package:sync/sync.dart' show SyncFailure;

// Synthetic public outputs only: no wallet keys, signatures or real funds.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => BullSdk.init());

  test('real blinded PSET retains amount metadata after extraction hides it', () async {
    // Public output and proofs from rust-elements 0.26.2's CC0 swap tutorial
    // fixture. Inputs and derivation metadata are omitted; no keys are stored.
    final fromRoot = File(
      'packages/sync/native_test/fixtures/confidential_output.pset',
    );
    final pset = fromRoot.existsSync()
        ? fromRoot
        : File('native_test/fixtures/confidential_output.pset');
    final encoded = (await pset.readAsString()).trim();
    final parsed = lwk.PartiallySignedElementsTransaction.fromString(
      psetString: encoded,
    );
    final output = parsed.getOutputs().single;
    expect(parsed.extractTx().getOutputs().single.value, isNull);
    final address = await lwk.Address.addressFromScript(
      network: lwk.LiquidNetwork.regtest,
      script: output.scriptPubkey,
      blindingKey: output.blindingKey,
    );
    final asset = output.asset;
    if (asset == null) fail('The public fixture must retain the asset');
    final result = await liquidPsetAmountToAddress(
      encoded,
      address.confidential,
      network: LiquidNetwork.regtest,
      policyAsset: asset,
    );
    expect(
      result,
      isA<Ok<BigInt, SyncFailure>>().having(
        (result) => result.value,
        'destination amount',
        BigInt.from(250000000000),
      ),
    );
  });

  test(
    'real PSET parser preserves confidential output amounts and destination',
    () async {
      const script = '00141111111111111111111111111111111111111111';
      const otherScript = '00142222222222222222222222222222222222222222';
      const publicPoint =
          '0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
      final asset = '11' * 32;
      final destination = await lwk.Address.addressFromScript(
        network: lwk.LiquidNetwork.regtest,
        script: script,
        blindingKey: publicPoint,
      );
      final pset = _pset([
        _output(script, 10, publicPoint),
        _output(script, 20, publicPoint),
        _output(otherScript, 80, publicPoint),
        _output('', 5, null),
      ]);
      final lwk.PartiallySignedElementsTransaction parsed;
      try {
        parsed = lwk.PartiallySignedElementsTransaction.fromString(
          psetString: pset,
        );
      } on lwk.LwkError catch (error) {
        fail(error.msg);
      }
      expect(parsed.getOutputs().first.amount, BigInt.from(10));

      final result = await liquidPsetAmountToAddress(
        pset,
        destination.confidential,
        network: LiquidNetwork.regtest,
        policyAsset: asset,
      );
      expect(
        result,
        isA<Ok<BigInt, SyncFailure>>().having(
          (result) => result.value,
          'destination amount',
          BigInt.from(30),
        ),
      );
    },
  );
}

List<int> _hex(String value) => [
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
];
List<int> _pair(List<int> key, List<int> value) => [
  key.length,
  ...key,
  value.length,
  ...value,
];
List<int> _number(int value, int size) {
  final bytes = ByteData(size);
  if (size == 4) {
    bytes.setUint32(0, value, Endian.little);
  } else {
    bytes.setUint64(0, value, Endian.little);
  }
  return bytes.buffer.asUint8List();
}

List<int> _output(String script, int amount, String? blindingKey) => [
  ..._pair([3], _number(amount, 8)),
  ..._pair([4], _hex(script)),
  ..._pair([0xfc, 4, ...ascii.encode('pset'), 2], List.filled(32, 0x11)),
  if (blindingKey != null)
    ..._pair([0xfc, 4, ...ascii.encode('pset'), 8], _number(0, 4)),
  if (blindingKey != null)
    ..._pair([0xfc, 4, ...ascii.encode('pset'), 6], _hex(blindingKey)),
  0,
];
String _pset(List<List<int>> outputs) => base64.encode([
  ...ascii.encode('pset'),
  0xff,
  ..._pair([0xfb], _number(2, 4)),
  ..._pair([2], _number(2, 4)),
  ..._pair([4], [0]),
  ..._pair([5], [outputs.length]),
  0,
  for (final output in outputs) ...output,
]);
