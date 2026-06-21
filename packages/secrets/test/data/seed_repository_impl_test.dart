import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/datasources/fss_secret_store.dart';
import 'package:secrets/src/data/seed_repository_impl.dart';
import 'package:secrets/src/domain/seed_index.dart';
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

({SeedRepositoryImpl repo, FakeSecureKeyValueStore kv, _FakeSeedIndex index})
    _make() {
  final kv = FakeSecureKeyValueStore();
  final index = _FakeSeedIndex();
  final repo = SeedRepositoryImpl(
    store: FssSecretStore(kv, initialRetryDelay: Duration.zero),
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
      expect(infos.single.kind, SeedKind.mnemonic);
      expect(infos.single.wordCount, 12);
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

  group('importBytes', () {
    test('stores a bytes-only seed', () async {
      final m = _make();
      final res =
          await m.repo.importBytes(Uint8List.fromList(List.filled(32, 3)));
      expect(res, isA<Ok>());
      final infos = _unwrap(await m.repo.listSeeds());
      expect(infos.single.kind, SeedKind.bytesOnly);
      expect(infos.single.wordCount, isNull);
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
