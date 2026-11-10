import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart' as convert;

import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
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
  late FakeSecureStoragePlatform storage;

  setUp(() async {
    storage = FakeSecureStoragePlatform()..install();
    secret = ok(
      await Secrets(scratchDirectory: () async => '/tmp').import(words: words),
    );
  });

  test('signs the published Japanese seed with its passphrase', () async {
    final japanese = ok(
      await Secrets(scratchDirectory: () async => '/tmp').import(
        words: [...List.filled(11, 'あいこくしん'), 'あおぞら'],
        language: bip39.Language.japanese,
        passphrase: 'メートルガバヴァぱばぐゞちぢ十人十色',
      ),
    );
    final fixture = _witnessPsbt(
      seed: Uint8List.fromList(
        convert.hex.decode(
          'a262d6fb6122ecf45be09c50492b31f92e9beb7d9a845987a02cefda57a15f9c'
          '467a17872029a9e92299b5cbdf306e3a0ee620245cbd508959b6cb7ca637bd55',
        ),
      ),
    );
    final signed = ok(
      await japanese.sign.psbt(
        fixture.psbt,
        network: BitcoinNetwork.mainnet,
        scriptType: ScriptType.bip84,
      ),
    );
    final parsed = bdk.Psbt(psbtBase64: signed);
    final tx = parsed.extractTx();
    final input = tx.input().single;
    try {
      expect(input.witness, hasLength(2));
      expect(input.witness.first.last, 1);
      expect(input.witness.last, fixture.publicKey);
    } finally {
      input.scriptSig.dispose();
      tx.dispose();
      parsed.dispose();
    }
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
  group('sign.descriptorPsbt', () {
    for (final language in [Language.english, Language.japanese]) {
      final sourceWords = bip39.Mnemonic(List.filled(16, 0), language).words;
      test(
        '${language.name} temporary signing preserves storage and partial signatures',
        () async {
          secret = ok(
            await Secrets(scratchDirectory: () async => '/tmp').import(
              words: sourceWords,
              language: language,
              passphrase: 'stored',
            ),
          );
          final stored = Map<String, String>.of(storage.entries);
          final storedId = secret.id;
          const path = "m/84'/0'/1'";
          final account = ok(
            await secret.derive.account(
              derivationPath: path,
              network: BitcoinNetwork.mainnet,
              passphrase: 'operation',
            ),
          );
          final expression =
              "[${account.fingerprint.hex}/84'/0'/1']${account.xpub}/<0;1>/*";
          final signed = ok(
            await secret.sign.descriptorPsbt(
              _witnessPsbt(
                accountIndex: 1,
                seed: Uint8List.fromList(
                  bip39.Mnemonic.fromWords(
                    words: sourceWords,
                    language: language,
                    passphrase: 'operation',
                  ).seed,
                ),
              ).psbt,
              descriptor: 'wpkh($expression)',
              passphrase: 'operation',
              network: BitcoinNetwork.mainnet,
              keys: [
                DescriptorSigningKey(
                  publicExpression: expression,
                  derivationPath: path,
                  xpub: account.xpub,
                ),
              ],
            ),
          );
          expect(secret.id, storedId);
          expect(account.fingerprint, isNot(storedId));
          expect(storage.entries, stored);
          final parsed = bdk.Psbt(psbtBase64: signed);
          try {
            final input = parsed.input().single;
            expect(input.partialSigs, hasLength(1));
            expect(input.finalScriptWitness, isNull);
          } finally {
            parsed.dispose();
          }
        },
      );
    }

    test(
      'raw seeds sign descriptors without adding passphrase support',
      () async {
        final raw = FakeSecureStoragePlatform(
          entries: {
            'seed_73c5da0a': jsonEncode({
              'bytes': bip39.Mnemonic.fromWords(words: words).seed,
              'runtimeType': 'bytes',
            }),
          },
        )..install();
        final seed = ok(
          await Secrets(
            scratchDirectory: () async => '/tmp',
          ).fetch(Fingerprint('73c5da0a')),
        );
        final entries = Map<String, String>.of(raw.entries);
        const path = "m/84'/0'/1'";
        final account = ok(
          await seed.derive.account(
            derivationPath: path,
            network: BitcoinNetwork.mainnet,
            passphrase: '',
          ),
        );
        final expression = "[73c5da0a/84'/0'/1']${account.xpub}/<0;1>/*";
        final keys = [
          DescriptorSigningKey(
            publicExpression: expression,
            derivationPath: path,
            xpub: account.xpub,
          ),
        ];
        final signed = ok(
          await seed.sign.descriptorPsbt(
            _witnessPsbt(accountIndex: 1).psbt,
            descriptor: 'wpkh($expression)',
            network: BitcoinNetwork.mainnet,
            keys: keys,
            passphrase: '',
          ),
        );
        final parsed = bdk.Psbt(psbtBase64: signed);
        try {
          expect(parsed.input().single.partialSigs, hasLength(1));
        } finally {
          parsed.dispose();
        }
        expect(
          err(
            await seed.sign.descriptorPsbt(
              _witnessPsbt(accountIndex: 1).psbt,
              descriptor: 'wpkh($expression)',
              network: BitcoinNetwork.mainnet,
              keys: keys,
              passphrase: 'not supported',
            ),
          ),
          isA<PassphraseUnsupportedFailure>(),
        );
        expect(raw.entries, entries);
      },
    );

    test(
      'refuses a selected xpub that is not derived by this secret',
      () async {
        final account = ok(
          await secret.derive.account(
            derivationPath: "m/84'/0'/1'",
            network: BitcoinNetwork.mainnet,
          ),
        );
        final expression =
            "[${account.fingerprint.hex}/84'/0'/1']${account.xpub}/<0;1>/*";
        final failure = err(
          await secret.sign.descriptorPsbt(
            _witnessPsbt(accountIndex: 1).psbt,
            descriptor: 'wpkh($expression)',
            network: BitcoinNetwork.mainnet,
            keys: [
              DescriptorSigningKey(
                publicExpression: expression,
                derivationPath: "m/84'/0'/0'",
                xpub: account.xpub,
              ),
            ],
          ),
        );
        expect(failure, isA<UseSecretFailure>());
        expect(failure.logMessage, isNot(contains('xprv')));
      },
    );
  });
}

/// A PSBT v0 with one synthetic P2WPKH UTXO belonging to the public BIP39 fixture. Its witness UTXO and BIP32 origin carry everything an offline signer needs (BIP174: https://github.com/bitcoin/bips/blob/master/bip-0174.mediawiki).
({String psbt, List<int> publicKey}) _witnessPsbt({
  int accountIndex = 0,
  Uint8List? seed,
}) {
  // The same published abandon…about master key pinned in derivation_vectors_test.dart.
  final root = seed != null
      ? Bip32Keys.fromSeed(seed)
      : Bip32Keys.fromBase58(
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
