import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/data/seed_reconciler.dart';
import 'package:secrets/src/domain/ports/secret_index_port.dart';
import 'package:secrets/src/domain/value_objects/secret_info.dart';

import 'fake_secure_key_value_store.dart';

FssSecretStoreAdapter _store(FakeSecureKeyValueStore kv) =>
    // zero retry delay so tests don't sleep
    FssSecretStoreAdapter(kv, initialRetryDelay: Duration.zero);

class _FakeSeedIndex implements SecretIndexPort {
  final Map<String, SecretInfo> _m = {};
  @override
  Future<List<SecretInfo>> all() async => _m.values.toList();
  @override
  Future<SecretInfo?> get(Fingerprint fp) async => _m[fp.hex];
  @override
  Future<void> remove(Fingerprint fp) async => _m.remove(fp.hex);
  @override
  Future<void> upsert(SecretInfo info) async => _m[info.fingerprint.hex] = info;
}

void main() {
  group('FssSecretStoreAdapter round-trip', () {
    test('store then useAndForget exposes the bytes, then zeroes the buffer',
        () async {
      final kv = FakeSecureKeyValueStore();
      final store = _store(kv);
      final bytes = Uint8List.fromList([1, 2, 3, 4]);

      await store.store(SecretStoreKeys.seedKey('deadbeef'), bytes);
      // Copy inside the callback: the live buffer is the caller's only during
      // `use`; §5.5 zeroes it in a `finally` the instant the callback returns.
      late final Uint8List leaked;
      final copy = await store.useAndForget(
        SecretStoreKeys.seedKey('deadbeef'),
        (b) async {
          leaked = b;
          return Uint8List.fromList(b);
        },
      );
      expect(copy, [1, 2, 3, 4]); // the callback saw the cleartext
      expect(leaked, [0, 0, 0, 0]); // …but the live buffer was wiped after use
    });

    test('values are stored base64-encoded, never in the clear', () async {
      final kv = FakeSecureKeyValueStore();
      final store = _store(kv);
      final bytes = Uint8List.fromList([255, 0, 128]);
      await store.store(SecretStoreKeys.seedKey('deadbeef'), bytes);
      final raw = (await kv.readAll())[SecretStoreKeys.seedKey('deadbeef')];
      expect(raw, 's1:${base64.encode(bytes)}'); // versioned, base64 at rest
      expect(raw, isNot(contains(String.fromCharCodes(bytes)))); // never cleartext
    });

    test('store throws if the key already exists (no silent overwrite)',
        () async {
      final kv = FakeSecureKeyValueStore();
      final store = _store(kv);
      final key = SecretStoreKeys.seedKey('deadbeef');
      await store.store(key, Uint8List.fromList([1]));
      expect(
        () => store.store(key, Uint8List.fromList([2])),
        throwsA(isA<SecretAlreadyExistsException>()),
      );
    });

    test('exists / trash / purge', () async {
      final kv = FakeSecureKeyValueStore();
      final store = _store(kv);
      final key = SecretStoreKeys.seedKey('deadbeef');
      await store.store(key, Uint8List.fromList([1]));
      expect(await store.exists(key), isTrue);
      await store.trash(key);
      expect(await store.exists(key), isFalse);

      await store.store(SecretStoreKeys.seedKey('aaaa0000'), Uint8List(1));
      await store.purge();
      expect(await store.keys(), isEmpty);
    });

    test('SECURITY: purge wipes ONLY seed keys, never app-owned secrets',
        () async {
      final kv = FakeSecureKeyValueStore()
        ..seed(SecretStoreKeys.seedKey('deadbeef'), 's1:AA==')
        ..seed('a1b2c3d4', 'legacy-raw-fp-seed') // legacy seed → also purged
        ..seed('swap_xyz', 'per-swap-keypair') // app-owned → MUST survive
        ..seed(SecretStoreKeys.legacyHiveEncryption, 'hive-key') // MUST survive
        ..seed('pin', '0000'); // app-owned → MUST survive
      final store = _store(kv);
      await store.purge();
      final remaining = await store.keys();
      expect(remaining, contains('swap_xyz'));
      expect(remaining, contains(SecretStoreKeys.legacyHiveEncryption));
      expect(remaining, contains('pin'));
      expect(remaining, isNot(contains(SecretStoreKeys.seedKey('deadbeef'))));
      expect(remaining, isNot(contains('a1b2c3d4')));
    });
  });

  group('SECURITY: keychain locked is rethrown, never converted', () {
    test('useAndForget rethrows KeychainLockedException immediately', () async {
      final kv = FakeSecureKeyValueStore()..locked = true;
      final store = _store(kv);
      await expectLater(
        store.useAndForget(SecretStoreKeys.seedKey('deadbeef'), (b) async => b),
        throwsA(isA<KeychainLockedException>()),
      );
    });
  });

  group('legacy non-base64 value handling', () {
    test('a legacy raw-UTF-8 (JSON) value is decoded, not thrown on', () async {
      final kv = FakeSecureKeyValueStore();
      final store = _store(kv);
      // Simulate a legacy seed stored as raw JSON (not base64).
      kv.seed('a1b2c3d4', '{"type":"mnemonic"}');
      final got = await store.useAndForget(
          'a1b2c3d4', (b) async => String.fromCharCodes(b));
      expect(got, '{"type":"mnemonic"}');
    });
  });

  group('eventual-consistency backoff', () {
    test('retries transient null reads then succeeds', () async {
      final kv = FakeSecureKeyValueStore();
      final store = _store(kv);
      final key = SecretStoreKeys.seedKey('deadbeef');
      await store.store(key, Uint8List.fromList([9]));
      kv.transientNullReads = 3; // null, null, null, then the value
      final got = await store.useAndForget(key, (b) async => b.first);
      expect(got, 9);
    });
  });

  group('keys() enumeration incl. legacy patterns', () {
    test('surfaces seed_, legacy raw-fingerprint, hive and swap keys',
        () async {
      final kv = FakeSecureKeyValueStore()
        ..seed(SecretStoreKeys.seedKey('deadbeef'), 'x')
        ..seed('a1b2c3d4', 'legacy-raw-fp') // legacy unprefixed seed
        ..seed(SecretStoreKeys.legacyHiveEncryption, 'k')
        ..seed('${SecretStoreKeys.legacySwapTxSensitivePrefix}1', 'k');
      final store = _store(kv);
      final keys = await store.keys();
      expect(keys, contains(SecretStoreKeys.seedKey('deadbeef')));
      expect(keys, contains('a1b2c3d4'));
      expect(keys, contains(SecretStoreKeys.legacyHiveEncryption));
      expect(SecretStoreKeys.isSeedKey('a1b2c3d4'), isTrue);
      expect(SecretStoreKeys.isSeedKey(SecretStoreKeys.legacyHiveEncryption),
          isFalse);
    });
  });

  group('reconcileSeeds', () {
    test('clean when index and store agree', () async {
      final kv = FakeSecureKeyValueStore();
      final store = _store(kv);
      final index = _FakeSeedIndex();
      await store.store(SecretStoreKeys.seedKey('deadbeef'), Uint8List(1));
      await index.upsert(SecretInfo(
        fingerprint: Fingerprint('deadbeef'),
        kind: SecretKind.mnemonic,
        wordCount: 12,
        hasPassphrase: false,
        language: 'english',
      ));
      final report = await reconcileSeeds(index: index, store: store);
      expect(report.isClean, isTrue);
    });

    test('orphan store key (no index entry) is reported for self-heal',
        () async {
      final kv = FakeSecureKeyValueStore();
      final store = _store(kv);
      final index = _FakeSeedIndex();
      await store.store(SecretStoreKeys.seedKey('deadbeef'), Uint8List(1));
      final report = await reconcileSeeds(index: index, store: store);
      expect(report.orphanSeedFingerprints, [Fingerprint('deadbeef')]);
      expect(report.danglingIndexFingerprints, isEmpty);
    });

    test('dangling index entry (no store key) is surfaced, never dropped',
        () async {
      final kv = FakeSecureKeyValueStore();
      final store = _store(kv);
      final index = _FakeSeedIndex();
      await index.upsert(SecretInfo(
        fingerprint: Fingerprint('cafebabe'),
        kind: SecretKind.mnemonic,
        wordCount: 12,
        hasPassphrase: false,
        language: 'english',
      ));
      final report = await reconcileSeeds(index: index, store: store);
      expect(report.danglingIndexFingerprints, [Fingerprint('cafebabe')]);
      expect(report.orphanSeedFingerprints, isEmpty);
    });

    test('a malformed seed_-prefixed key is surfaced, not silently dropped',
        () async {
      final kv = FakeSecureKeyValueStore()
        ..seed('${SecretStoreKeys.seed}nothex!!', 'x');
      final store = _store(kv);
      final report = await reconcileSeeds(index: _FakeSeedIndex(), store: store);
      expect(report.malformedKeys, contains('${SecretStoreKeys.seed}nothex!!'));
      expect(report.isClean, isFalse);
    });
  });
}
