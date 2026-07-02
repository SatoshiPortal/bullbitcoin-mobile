
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'dart:typed_data';

import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/adapters/secret_lifecycle_adapter.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/domain/ports/secret_index_port.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/secret_info.dart';

import 'fake_secure_key_value_store.dart';

const zooWords = [
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'zoo', //
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'wrong',
];

T _unwrap<T>(Result<T, SecretsFailure> r) => switch (r) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError('expected Ok, got $failure'),
    };

SecretsFailure _unwrapErr<T>(Result<T, SecretsFailure> r) => switch (r) {
      Ok() => throw StateError('expected Err, got Ok'),
      Err(:final failure) => failure,
    };

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

({SecretLifecycleAdapter repo, FakeSecureKeyValueStore kv, _FakeSeedIndex index})
    _make() {
  final kv = FakeSecureKeyValueStore();
  final index = _FakeSeedIndex();
  final repo = SecretLifecycleAdapter(
    store: FssSecretStoreAdapter(kv, initialRetryDelay: Duration.zero),
    index: index,
  );
  return (repo: repo, kv: kv, index: index);
}

void main() {
  group('importMnemonic', () {
    test('happy path stores + indexes + returns the fingerprint', () async {
      final m = _make();
      final res = await m.repo.importMnemonic(words: zooWords);
      expect(res, isA<Ok<Fingerprint, SecretsFailure>>());
      final fp = _unwrap(res);
      expect(_unwrap(await m.repo.exists(fp)), isTrue);
      final infos = _unwrap(await m.repo.listSeeds());
      expect(infos, hasLength(1));
      expect(infos.single.wordCount, 12);
      expect(infos.single.language, 'english');
    });

    test('duplicate fingerprint is rejected (collision-safe handle)', () async {
      final m = _make();
      await m.repo.importMnemonic(words: zooWords);
      final res = await m.repo.importMnemonic(words: zooWords);
      expect(res, isA<Err<Fingerprint, SecretsFailure>>());
      expect(_unwrapErr(res), isA<DuplicateSecretFailure>());
    });

    test('invalid mnemonic → InvalidMnemonicFailure (not a crash)', () async {
      final m = _make();
      final res = await m.repo.importMnemonic(
        words: List.filled(12, 'zoo'), // bad checksum
      );
      expect(res, isA<Err>());
      expect(_unwrapErr(res), isA<InvalidMnemonicFailure>());
    });

    test('keychain locked → KeychainLockedFailure, never not-found', () async {
      final m = _make();
      m.kv.locked = true;
      final res = await m.repo.importMnemonic(words: zooWords);
      expect(_unwrapErr(res), isA<KeychainLockedFailure>());
    });

    test('a backend that ACKS but persists CORRUPT bytes → fail, never indexed',
        () async {
      // store() trusts a non-throwing write; the read-back verify catches a
      // backend that acked but dropped/corrupted the write, so a fresh seed the
      // user may have no other copy of is never reported as stored.
      final store = _CorruptingStore();
      final index = _FakeSeedIndex();
      final repo = SecretLifecycleAdapter(store: store, index: index);

      final res = await repo.importMnemonic(words: zooWords);
      expect(res, isA<Err>());
      expect(_unwrapErr(res), isA<SecretsUnexpectedFailure>());
      expect(await index.all(), isEmpty); // never indexed
      expect(store.trashed, isNotEmpty); // the bad write was trashed
    });
  });

  group('generateMnemonic', () {
    test('generates, stores and indexes a 12-word seed', () async {
      final m = _make();
      final res = await m.repo.generateMnemonic();
      expect(res, isA<Ok>());
      final infos = _unwrap(await m.repo.listSeeds());
      expect(infos.single.wordCount, 12);
    });
  });

  group('importMnemonic with passphrase', () {
    test('a passphrase yields a different fingerprint + hasPassphrase flag',
        () async {
      final m = _make();
      final noPass = _unwrap(await m.repo.importMnemonic(words: zooWords));
      final withPass = _unwrap(
          await m.repo.importMnemonic(words: zooWords, passphrase: 'x'));
      expect(withPass, isNot(noPass)); // BIP39: passphrase changes the seed
      final infos = _unwrap(await m.repo.listSeeds());
      expect(infos.firstWhere((i) => i.fingerprint == withPass).hasPassphrase,
          isTrue);
    });
  });

  group('fingerprintOf', () {
    test('derives without storing', () async {
      final m = _make();
      final res = await m.repo.fingerprintOf(words: zooWords);
      expect(res, isA<Ok>());
      final infos = _unwrap(await m.repo.listSeeds());
      expect(infos, isEmpty); // nothing stored
    });
  });

  group('delete + getInfo', () {
    test('delete removes from store and index', () async {
      final m = _make();
      final fp = _unwrap(await m.repo.importMnemonic(words: zooWords));
      await m.repo.delete(fp);
      expect(_unwrap(await m.repo.exists(fp)), isFalse);
      expect(_unwrap(await m.repo.getInfo(fp)), isNull);
    });
  });
}

/// A store that ACKS the write but persists DIFFERENT bytes — models a backend
/// that silently drops/corrupts (the reason the migrator and _persist byte-verify).
class _CorruptingStore implements SecretStorePort {
  final Map<String, Uint8List> _m = {};
  final List<String> trashed = [];
  @override
  Future<void> init() async {}
  @override
  StoreCapabilities capabilities() => const StoreCapabilities(
      hardwareBacked: false, thisDeviceOnly: true, syncable: false);
  @override
  Future<void> store(String key, Uint8List value) async =>
      _m[key] = Uint8List.fromList([value.isEmpty ? 0 : value.first ^ 0xFF]);
  @override
  Future<bool> exists(String key) async => _m.containsKey(key);
  @override
  Future<R> useAndForget<R>(String key, Future<R> Function(Uint8List) use) async {
    final v = _m[key];
    if (v == null) throw SecretNotFoundException(key);
    return use(Uint8List.fromList(v));
  }
  @override
  Future<void> trash(String key) async {
    trashed.add(key);
    _m.remove(key);
  }
  @override
  Future<void> purge() async => _m.clear();
  @override
  Future<List<String>> keys() async => _m.keys.toList();
}
