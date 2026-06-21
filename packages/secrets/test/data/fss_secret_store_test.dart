import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/datasources/fss_secret_store.dart';
import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/data/seed_reconciler.dart';
import 'package:secrets/src/domain/seed_index.dart';
import 'package:secrets/src/domain/value_objects/seed_info.dart';

import 'fake_secure_key_value_store.dart';

FssSecretStore _store(FakeSecureKeyValueStore kv) =>
    // zero retry delay so tests don't sleep
    FssSecretStore(kv, initialRetryDelay: Duration.zero);

class _FakeSeedIndex implements SeedIndex {
  final Map<String, SeedInfo> _m = {};
  @override
  Future<List<SeedInfo>> all() async => _m.values.toList();
  @override
  Future<SeedInfo?> get(Fingerprint fp) async => _m[fp.hex];
  @override
  Future<void> remove(Fingerprint fp) async => _m.remove(fp.hex);
  @override
  Future<void> upsert(SeedInfo info) async => _m[info.fingerprint.hex] = info;
}

void main() {
  group('FssSecretStore round-trip', () {
    test('store then useAndForget returns the bytes', () async {
      final kv = FakeSecureKeyValueStore();
      final store = _store(kv);
      final bytes = Uint8List.fromList([1, 2, 3, 4]);

      await store.store(SecretStoreKeys.seedKey('deadbeef'), bytes);
      final got = await store.useAndForget(
        SecretStoreKeys.seedKey('deadbeef'),
        (b) async => b,
      );
      expect(got, bytes);
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
      await index.upsert(SeedInfo(
        fingerprint: Fingerprint('deadbeef'),
        kind: SeedKind.mnemonic,
        hasPassphrase: false,
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
      await index.upsert(SeedInfo(
        fingerprint: Fingerprint('cafebabe'),
        kind: SeedKind.mnemonic,
        hasPassphrase: false,
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
