import 'dart:convert';

import 'package:bip32_keys/bip32_keys.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'result_helpers.dart';

/// Bitcoin signing through the public API and real BDK, using a synthetic witness UTXO for successful finalization and malformed inputs for failure classification. No chain connection or funded wallet is needed.
void main() {
  const words = [
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ];

  late Secret secret;

  setUpAll(() async {
    FakeSecureStoragePlatform().install();
    secret = ok(
      await Secrets(scratchDirectory: () async => '/tmp').import(words: words),
    );
  });

  group('sign.psbt', () {
    test('signs and finalizes a witness input without chain access', () async {
      final fixture = _witnessPsbt();
      final unsigned = bdk.Psbt(psbtBase64: fixture.psbt);
      final unsignedTx = unsigned.extractTx();
      final unsignedInput = unsignedTx.input().single;
      try {
        expect(unsignedInput.witness, isEmpty);
      } finally {
        unsignedInput.scriptSig.dispose();
        unsignedTx.dispose();
        unsigned.dispose();
      }

      final signed = ok(
        await secret.sign.psbt(
          fixture.psbt,
          network: BitcoinNetwork.mainnet,
          scriptType: ScriptType.bip84,
        ),
      );
      final parsed = bdk.Psbt(psbtBase64: signed);
      final transaction = parsed.extractTx();
      final input = transaction.input().single;
      try {
        expect(input.witness, hasLength(2));
        final signature = input.witness.first;
        expect(signature.length, greaterThan(8));
        expect(
          signature[1],
          signature.length - 3,
          reason: 'DER payload length',
        );
        expect(signature.first, 0x30, reason: 'a DER-encoded ECDSA signature');
        expect(signature.last, 1, reason: 'SIGHASH_ALL');
        expect(input.witness.last, fixture.publicKey);
        expect(parsed.fee(), 10000);
      } finally {
        input.scriptSig.dispose();
        transaction.dispose();
        parsed.dispose();
      }
    });

    test('account one signs its own input but account zero does not', () async {
      final fixture = _witnessPsbt(accountIndex: 1);
      final fromAccountZero = ok(
        await secret.sign.psbt(
          fixture.psbt,
          network: BitcoinNetwork.mainnet,
          scriptType: ScriptType.bip84,
        ),
      );
      final unmatched = bdk.Psbt(psbtBase64: fromAccountZero);
      final unmatchedTransaction = unmatched.extractTx();
      final unmatchedInput = unmatchedTransaction.input().single;
      try {
        expect(
          unmatchedInput.witness,
          isEmpty,
          reason: 'the default account must not claim an account-one input',
        );
      } finally {
        unmatchedInput.scriptSig.dispose();
        unmatchedTransaction.dispose();
        unmatched.dispose();
      }

      final signed = ok(
        await secret.sign.psbt(
          fixture.psbt,
          network: BitcoinNetwork.mainnet,
          scriptType: ScriptType.bip84,
          accountIndex: 1,
        ),
      );
      final parsed = bdk.Psbt(psbtBase64: signed);
      final transaction = parsed.extractTx();
      final input = transaction.input().single;
      try {
        expect(input.witness, hasLength(2));
        expect(input.witness.first.first, 0x30, reason: 'DER-encoded ECDSA');
        expect(input.witness.first.last, 1, reason: 'SIGHASH_ALL');
        expect(input.witness.last, fixture.publicKey);
        expect(parsed.fee(), 10000);
      } finally {
        input.scriptSig.dispose();
        transaction.dispose();
        parsed.dispose();
      }
    });

    test('refuses what is not a PSBT, by type only', () async {
      final result = await secret.sign.psbt(
        'not a psbt',
        network: BitcoinNetwork.mainnet,
        scriptType: ScriptType.bip84,
      );

      final failure = err(result);
      expect(failure, isA<UseSecretFailure>());
      // bdk's parse error quotes its input; none of it may travel.
      expect(failure.logMessage, isNot(contains('not a psbt')));
    });

    test(
      'refuses an invalid PSBT on every supported Bitcoin network',
      () async {
        // Every BitcoinNetwork maps to a bdk network, so this walks the wallet
        // build on each — testnet, signet and regtest share version bytes.
        for (final network in BitcoinNetwork.values) {
          final result = await secret.sign.psbt(
            'not a psbt',
            network: network,
            scriptType: ScriptType.bip84,
          );
          expect(err(result), isA<UseSecretFailure>(), reason: '$network');
        }
      },
    );
  });
}

/// A PSBT v0 with one synthetic P2WPKH UTXO belonging to the public BIP39 fixture. Its witness UTXO and BIP32 origin carry everything an offline signer needs (BIP174: https://github.com/bitcoin/bips/blob/master/bip-0174.mediawiki).
({String psbt, List<int> publicKey}) _witnessPsbt({int accountIndex = 0}) {
  // The same published abandon…about master key pinned in derivation_vectors_test.dart.
  final root = Bip32Keys.fromBase58(
    'xprv9s21ZrQH143K3GJpoapnV8SFfukcVBSfeCficPSGfubmSFDxo1kuHnLisriDv'
    'SnRRuL2Qrg5ggqHKNVpxR86QEC8w35uxmGoggxtQTPvfUu',
  );
  final child = root.derivePath("m/84'/0'/$accountIndex'/0/0");
  final script = [0x00, 0x14, ...child.identifier];
  final unsignedTransaction = [
    ..._littleEndian(2, 4), // version
    1, // input count
    ...List<int>.filled(32, 1), // synthetic previous transaction id
    ..._littleEndian(0, 4), // previous output index
    0, // empty scriptSig
    ..._littleEndian(0xffffffff, 4), // sequence
    1, // output count
    ..._littleEndian(90000, 8),
    script.length, ...script,
    ..._littleEndian(0, 4), // locktime
  ];
  final witnessUtxo = [..._littleEndian(100000, 8), script.length, ...script];
  final origin = [
    ...root.fingerprint,
    for (final index in [
      0x80000054,
      0x80000000,
      0x80000000 + accountIndex,
      0,
      0,
    ])
      ..._littleEndian(index, 4),
  ];
  return (
    psbt: base64Encode([
      0x70, 0x73, 0x62, 0x74, 0xff,
      ..._psbtEntry([0x00], unsignedTransaction),
      0, // global map end
      ..._psbtEntry([0x01], witnessUtxo),
      ..._psbtEntry([0x06, ...child.public], origin),
      0, // input map end
      0, // output map end
    ]),
    publicKey: child.public,
  );
}

List<int> _littleEndian(int value, int width) => [
  for (var index = 0; index < width; index++) (value >> (8 * index)) & 0xff,
];

List<int> _psbtEntry(List<int> key, List<int> value) {
  // Every entry in this fixture is short enough for one-byte CompactSize lengths.
  assert(key.length < 0xfd && value.length < 0xfd);
  return [key.length, ...key, value.length, ...value];
}
