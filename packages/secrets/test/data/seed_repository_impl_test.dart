
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/adapters/seed_adapter.dart';
import 'package:secrets/src/domain/ports/seed_index_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/seed_info.dart';

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

class _FakeSeedIndex implements SeedIndexPort {
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

({SeedAdapter repo, FakeSecureKeyValueStore kv, _FakeSeedIndex index})
    _make() {
  final kv = FakeSecureKeyValueStore();
  final index = _FakeSeedIndex();
  final repo = SeedAdapter(
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
      expect(_unwrapErr(res), isA<DuplicateSeedFailure>());
    });

    test('invalid mnemonic → InvalidMnemonicFailure (not a crash)', () async {
      final m = _make();
      final res = await m.repo.importMnemonic(
        words: List.filled(12, 'zoo'), // bad checksum
      );
      expect(res, isA<Err>());
      expect(_unwrapErr(res), isA<InvalidMnemonicFailure>());
    });

    test('unknown language is REJECTED on import (not silently English)',
        () async {
      // The import entry point must not misinterpret an unrecognized language
      // as English (the storage-decode path stays forward-compatible; this
      // user-facing edge is tightened).
      final m = _make();
      final res =
          await m.repo.importMnemonic(words: zooWords, language: 'klingon');
      expect(res, isA<Err>());
      expect(_unwrapErr(res), isA<InvalidMnemonicFailure>());
    });

    test('keychain locked → KeychainLockedFailure, never not-found', () async {
      final m = _make();
      m.kv.locked = true;
      final res = await m.repo.importMnemonic(words: zooWords);
      expect(_unwrapErr(res), isA<KeychainLockedFailure>());
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

    test('unknown language is rejected (does not misderive as English)',
        () async {
      final m = _make();
      final res =
          await m.repo.fingerprintOf(words: zooWords, language: 'klingon');
      expect(_unwrapErr(res), isA<InvalidMnemonicFailure>());
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
