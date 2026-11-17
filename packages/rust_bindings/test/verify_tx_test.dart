import 'dart:typed_data';

import 'package:rust_bindings/rust_bindings.dart';
import 'package:flutter_test/flutter_test.dart';

// GHSA-6jp4-8v48-cc5v guard, exercised the way a client uses it: before
// building a fee bump from a transaction the Electrum server put in the
// wallet's history, verify the wallet-owned inputs' signatures against their
// prevouts. A planted conflict carries the victim's inputs but cannot carry
// valid signatures over its redirected outputs.
//
// Fixtures come from the deterministic construction in
// rust/src/api/verify_tx.rs tests (key [1;32], p2wpkh, SIGHASH_ALL). The
// forged tx is byte-identical to the valid one except the output script —
// the advisory's attack shape: copied signatures, swapped destination.
//
// Loads the library the Native Assets hook builds for the host.
const _prevoutSpkHex = '001479b000887626b294a914501a4cd226b58b235983';
const _prevoutValueSat = 100000;
const _validTxHex =
    '0200000000010100000000000000000000000000000000000000000000000000000000000000000000000000fdffffff01905f010000000000160014670caa79e51d78ed0c583b89ff39d9c49b7199e7024730440220439cbfacc7bf1bca723eab9535a5b265022e7c06660d61a3089a28f1b1b2fd120220501d0d6a1ab6f022cea982de9eb0cc38324c511979b45a436403a51412673a650121031b84c5567b126440995d3ed5aaba0565d71e1834604819ff9c17f5e9d5dd078f00000000';
const _forgedTxHex =
    '0200000000010100000000000000000000000000000000000000000000000000000000000000000000000000fdffffff01905f0100000000001600144e2be896e0f48daa6fa6f7b644750fda930fffdb024730440220439cbfacc7bf1bca723eab9535a5b265022e7c06660d61a3089a28f1b1b2fd120220501d0d6a1ab6f022cea982de9eb0cc38324c511979b45a436403a51412673a650121031b84c5567b126440995d3ed5aaba0565d71e1834604819ff9c17f5e9d5dd078f00000000';

Uint8List _hex(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

List<TxInputToVerify> _ownedInputs() => [
  TxInputToVerify(
    inputIndex: 0,
    prevoutScriptPubkey: _hex(_prevoutSpkHex),
    prevoutValueSat: BigInt.from(_prevoutValueSat),
  ),
];

void main() {
  setUpAll(BullSdk.init);

  test('a transaction this wallet signed verifies as valid', () async {
    final result = await verifyTxInputSignatures(
      txBytes: _hex(_validTxHex),
      inputs: _ownedInputs(),
    );
    expect(result, isA<TxSignatureVerification_Valid>());
  });

  test(
    'a server-planted conflict (copied sigs, swapped output) is rejected',
    () async {
      final result = await verifyTxInputSignatures(
        txBytes: _hex(_forgedTxHex),
        inputs: _ownedInputs(),
      );
      expect(result, isA<TxSignatureVerification_InvalidSignatures>());
      final invalid = result as TxSignatureVerification_InvalidSignatures;
      expect(invalid.invalidInputIndexes, [0]);
    },
  );

  test('garbage bytes report malformed, not invalid', () async {
    final result = await verifyTxInputSignatures(
      txBytes: Uint8List.fromList([0xde, 0xad, 0xbe, 0xef]),
      inputs: _ownedInputs(),
    );
    expect(result, isA<TxSignatureVerification_Malformed>());
  });
}
