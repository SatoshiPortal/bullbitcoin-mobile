import 'package:secrets/src/data/datasources/malformed_secret_exception.dart';
// MIGRATION SAFETY — the highest-stakes test in the package.
//
// Proves that a seed written by the EXISTING app (and by pre-0.4 builds) is read
// back intact by this package, under the SAME storage key, so adopting the
// package never loses a user's funds. We write the exact historical on-disk
// JSON into the store and read it through the real FssSecretStoreAdapter +
// MnemonicReader + KeyDerivationAdapter (no native libs needed — pure Dart).
import 'dart:convert';
import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/models/mnemonic.dart';
import 'package:secrets/src/ui/mnemonic_reader.dart';

import '../data/fake_secure_key_value_store.dart';

const zooWords = [
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'zoo', //
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'wrong',
];
// Frozen package fingerprint for the zoo seed (BIP39→BIP32). The OLD app derives
// the SAME value (proven byte-identical), so the storage key matches.
const zooFingerprint = '3f635a63';

/// Exactly what the live app writes today: `jsonEncode(SeedModel.toJson())`
/// (freezed union → `runtimeType` discriminator, `mnemonicWords` field). No
/// base64, no `s1:` prefix.
String currentAppValue(List<String> words, {String? passphrase}) =>
    jsonEncode({
      'mnemonicWords': words,
      'passphrase': passphrase,
      'runtimeType': 'mnemonic',
    });

/// Pre-0.4 OldSeed JSON: single space-joined mnemonic + per-source passphrases.
String legacyOldSeedValue(List<String> words,
        {String fingerprint = zooFingerprint, String? passphrase}) =>
    jsonEncode({
      'mnemonic': words.join(' '),
      'mnemonicFingerprint': fingerprint,
      'network': 'bitcoin',
      'passphrases': [
        if (passphrase != null)
          {'passphrase': passphrase, 'sourceFingerprint': fingerprint},
      ],
    });

FssSecretStoreAdapter _store(FakeSecureKeyValueStore kv) =>
    FssSecretStoreAdapter(kv, initialRetryDelay: Duration.zero);

void main() {
  group('reads the CURRENT app seed format (universal user case)', () {
    test('12-word: words recovered AND fingerprint matches the storage key',
        () async {
      final kv = FakeSecureKeyValueStore()
        ..seed(SecretStoreKeys.seedKey(zooFingerprint), currentAppValue(zooWords));
      final store = _store(kv);

      // Read the raw stored bytes back into a Mnemonic (the migration decode).
      final m = await store.useAndForget(
        SecretStoreKeys.seedKey(zooFingerprint),
        (bytes) async => Mnemonic.fromStorageBytes(bytes),
      );

      expect(m.words, zooWords);
      // CRITICAL: the fingerprint the package derives equals the key the seed
      // was stored under — so the package FINDS it, not just parses it.
      expect(m.fingerprint.hex, zooFingerprint);
    });

    test('24-word round-trips', () async {
      final words = bip39.Mnemonic.generate(bip39.Language.english,
              length: bip39.MnemonicLength.words24)
          .words;
      final fp = Mnemonic(words: words).fingerprint.hex;
      final kv = FakeSecureKeyValueStore()
        ..seed(SecretStoreKeys.seedKey(fp), currentAppValue(words));
      final m = await _store(kv).useAndForget(
          SecretStoreKeys.seedKey(fp), (b) async => Mnemonic.fromStorageBytes(b));
      expect(m.words, words);
      expect(m.fingerprint.hex, fp);
    });

    test('with passphrase: recovered + flagged + distinct fingerprint',
        () async {
      const pass = 'correct horse';
      final fp = Mnemonic(words: zooWords, passphrase: pass).fingerprint.hex;
      expect(fp, isNot(zooFingerprint)); // passphrase changes the seed
      final kv = FakeSecureKeyValueStore()
        ..seed(SecretStoreKeys.seedKey(fp),
            currentAppValue(zooWords, passphrase: pass));
      final m = await _store(kv).useAndForget(
          SecretStoreKeys.seedKey(fp), (b) async => Mnemonic.fromStorageBytes(b));
      expect(m.words, zooWords);
      expect(m.passphrase, pass);
      expect(m.hasPassphrase, isTrue);
      expect(m.fingerprint.hex, fp);
    });

    test('the sealed MnemonicReader reads an old-format seed (display path)',
        () async {
      final kv = FakeSecureKeyValueStore()
        ..seed(SecretStoreKeys.seedKey(zooFingerprint), currentAppValue(zooWords));
      final reader = MnemonicReader(_store(kv));
      final data = await reader.read(Fingerprint(zooFingerprint));
      expect(data.words, zooWords);
    });
  });

  group('reads the pre-0.4 OldSeed format (legacy leftover)', () {
    test('space-joined mnemonic recovered, fingerprint matches', () async {
      final kv = FakeSecureKeyValueStore()
        ..seed(SecretStoreKeys.seedKey(zooFingerprint),
            legacyOldSeedValue(zooWords));
      final m = await _store(kv).useAndForget(
          SecretStoreKeys.seedKey(zooFingerprint),
          (b) async => Mnemonic.fromStorageBytes(b));
      expect(m.words, zooWords);
      expect(m.fingerprint.hex, zooFingerprint);
    });

    test('OldSeed is read as the BARE mnemonic even with a passphrases list',
        () async {
      // The raw-fp OldSeed key IS the bare-mnemonic fingerprint; its
      // `passphrases` list is metadata for DERIVED wallets (migrated separately
      // into their own passphrase-fingerprinted SeedModel). Attaching one here
      // would derive a DIFFERENT fingerprint than the key → an unfindable seed.
      // So the decoder must NOT guess a passphrase: bare mnemonic, null pass,
      // fingerprint == the bare key.
      final v = jsonEncode({
        'mnemonic': zooWords.join(' '),
        'mnemonicFingerprint': zooFingerprint,
        'network': 'bitcoin',
        'passphrases': [
          {'passphrase': '', 'sourceFingerprint': zooFingerprint},
          {'passphrase': 'TREZOR', 'sourceFingerprint': 'deadbeef'},
        ],
      });
      final kv = FakeSecureKeyValueStore()
        ..seed(SecretStoreKeys.seedKey(zooFingerprint), v);
      final m = await _store(kv).useAndForget(
          SecretStoreKeys.seedKey(zooFingerprint),
          (b) async => Mnemonic.fromStorageBytes(b));
      expect(m.words, zooWords);
      expect(m.passphrase, isNull); // never guessed from the list
      expect(m.fingerprint.hex, zooFingerprint); // bare fp == key → findable
    });
  });

  group('round-trips a value written by THIS package', () {
    test('new s1: format still reads', () async {
      final kv = FakeSecureKeyValueStore();
      final store = _store(kv);
      final original = Mnemonic(words: zooWords);
      await store.store(
          SecretStoreKeys.seedKey(zooFingerprint), original.toStorageBytes());
      final m = await store.useAndForget(
          SecretStoreKeys.seedKey(zooFingerprint),
          (b) async => Mnemonic.fromStorageBytes(b));
      expect(m.words, zooWords);
      expect(m.fingerprint.hex, zooFingerprint);
    });
  });

  group('decodes the package-native {kind:mnemonic} map (case 1)', () {
    test('raw kind:mnemonic JSON → words recovered AND fingerprint == key', () {
      final v = jsonEncode({
        'kind': 'mnemonic',
        'words': zooWords,
        'passphrase': null,
        'language': 'english',
      });
      final m = Mnemonic.fromStorageBytes(Uint8List.fromList(utf8.encode(v)));
      expect(m.words, zooWords);
      expect(m.fingerprint.hex, zooFingerprint); // findable under its own key
    });

    test('a map carrying BOTH mnemonicWords AND bytes resolves to the mnemonic',
        () {
      // Precedence guard: a stray `bytes` field must never shadow real words and
      // get the value wrongly rejected as bytes-only.
      final v = jsonEncode({
        'mnemonicWords': zooWords,
        'runtimeType': 'mnemonic',
        'bytes': [1, 2, 3],
      });
      final m = Mnemonic.fromStorageBytes(Uint8List.fromList(utf8.encode(v)));
      expect(m.words, zooWords);
      expect(m.fingerprint.hex, zooFingerprint);
    });
  });

  group('SAFETY: malformed/unsupported never silently loses or crashes', () {
    test('bytes-only seed is explicitly rejected (not silently accepted)', () {
      final v = jsonEncode({'bytes': [1, 2, 3], 'runtimeType': 'bytes'});
      expect(
        () => Mnemonic.fromStorageBytes(Uint8List.fromList(utf8.encode(v))),
        throwsA(isA<MalformedSecretException>()),
      );
    });

    test('unrecognized JSON → MalformedSecretException (catchable, not an Error)', () {
      final v = jsonEncode({'something': 'else'});
      expect(
        () => Mnemonic.fromStorageBytes(Uint8List.fromList(utf8.encode(v))),
        throwsA(isA<MalformedSecretException>()),
      );
    });

    test('whitespace-only OldSeed mnemonic → MalformedSecretException (no empty seed)',
        () {
      // `{"mnemonic":"   "}` passes a bare `.isNotEmpty` but decodes to a
      // degenerate single-empty-word mnemonic; the `.trim().isNotEmpty` guard
      // must reject it like any other unrecognized format.
      final v = jsonEncode({'mnemonic': '   '});
      expect(
        () => Mnemonic.fromStorageBytes(Uint8List.fromList(utf8.encode(v))),
        throwsA(isA<MalformedSecretException>()),
      );
    });
  });
}
