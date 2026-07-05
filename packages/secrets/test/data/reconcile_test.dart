import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/adapters/secret_lifecycle_adapter.dart';
import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/data/migration/reconcile_report.dart';
import 'package:secrets/src/domain/ports/secret_index_port.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/secret_info.dart';

import 'fake_secure_key_value_store.dart';

// Two valid, distinct BIP39 mnemonics (different fingerprints).
const _zooWords = [
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'zoo', //
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'wrong',
];
const _abandonWords = [
  'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'abandon', //
  'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'about',
];

class _FakeSeedIndex implements SecretIndexPort {
  final Map<String, SecretInfo> m = {};
  @override
  Future<List<SecretInfo>> all() async => m.values.toList();
  @override
  Future<SecretInfo?> get(Fingerprint fp) async => m[fp.hex];
  @override
  Future<void> remove(Fingerprint fp) async => m.remove(fp.hex);
  @override
  Future<void> upsert(SecretInfo info) async => m[info.fingerprint.hex] = info;
}

/// A store whose enumeration is locked — models a keychain locked at startup.
class _LockedStore implements SecretStorePort {
  @override
  Future<void> init() async {}
  @override
  StoreCapabilities capabilities() => const StoreCapabilities(
    hardwareBacked: false,
    thisDeviceOnly: true,
    syncable: false,
  );
  @override
  Future<List<String>> keys() async => throw const KeychainLockedException();
  @override
  Future<bool> exists(String key) async =>
      throw const KeychainLockedException();
  @override
  Future<R> useAndForget<R>(
    String key,
    Future<R> Function(Uint8List) use,
  ) async => throw const KeychainLockedException();
  @override
  Future<void> store(String key, Uint8List value) async =>
      throw const KeychainLockedException();
  @override
  Future<void> trash(String key) async => throw const KeychainLockedException();
  @override
  Future<void> purge() async => throw const KeychainLockedException();
}

({SecretLifecycleAdapter repo, _FakeSeedIndex index}) _make(
  FakeSecureKeyValueStore kv,
) {
  final index = _FakeSeedIndex();
  final repo = SecretLifecycleAdapter(
    store: FssSecretStoreAdapter(kv, initialRetryDelay: Duration.zero),
    index: index,
  );
  return (repo: repo, index: index);
}

Fingerprint _fp<T>(Result<T, SecretsFailure> r) => switch (r) {
  Ok(:final value) when value is Fingerprint => value,
  _ => throw StateError('expected Ok(Fingerprint), got $r'),
};

ReconcileReport _report(Result<ReconcileReport, SecretsFailure> r) =>
    switch (r) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError('expected Ok, got $failure'),
    };

void main() {
  group('SecretLifecycleAdapter.reconcile', () {
    test('clean when index and store already agree', () async {
      final m = _make(FakeSecureKeyValueStore());
      await m.repo.importMnemonic(words: _zooWords);
      final report = _report(await m.repo.reconcile());
      expect(report.isClean, isTrue);
      expect(report.didWork, isFalse);
      expect(report.healed, 0);
    });

    test('heals an orphan (secret in store, missing from index)', () async {
      final m = _make(FakeSecureKeyValueStore());
      final fp = _fp(await m.repo.importMnemonic(words: _zooWords));
      // Simulate the non-atomic-import failure: the store write landed, the
      // index upsert did not.
      m.index.m.clear();
      expect(await m.index.get(fp), isNull);

      final report = _report(await m.repo.reconcile());

      expect(report.healed, 1);
      expect(report.didWork, isTrue);
      expect(report.failures, isEmpty);
      // The secret is findable again — its non-secret info is back in the index.
      final healed = await m.index.get(fp);
      expect(healed, isNotNull);
      expect(healed!.fingerprint, fp);
      expect(healed.wordCount, 12);
      expect(healed.createdAt, isNull); // unknown for a healed orphan
    });

    test('rebuilds the ENTIRE index from the store (index-DB loss)', () async {
      final m = _make(FakeSecureKeyValueStore());
      final fp1 = _fp(await m.repo.importMnemonic(words: _zooWords));
      final fp2 = _fp(await m.repo.importMnemonic(words: _abandonWords));
      // Total index loss: the store still holds both secrets, the index is empty.
      m.index.m.clear();

      final report = _report(await m.repo.reconcile());

      expect(report.healed, 2);
      expect(await m.index.get(fp1), isNotNull);
      expect(await m.index.get(fp2), isNotNull);
    });

    test('is idempotent — a second pass is clean', () async {
      final m = _make(FakeSecureKeyValueStore());
      await m.repo.importMnemonic(words: _zooWords);
      m.index.m.clear();
      expect(_report(await m.repo.reconcile()).healed, 1);
      final second = _report(await m.repo.reconcile());
      expect(second.isClean, isTrue);
      expect(second.healed, 0);
    });

    test('surfaces a dangling index entry, never heals/drops it', () async {
      final m = _make(FakeSecureKeyValueStore());
      await m.index.upsert(
        SecretInfo(
          fingerprint: Fingerprint('cafebabe'),
          kind: SecretKind.mnemonic,
          wordCount: 12,
          hasPassphrase: false,
          language: 'english',
        ),
      );
      final report = _report(await m.repo.reconcile());
      expect(report.healed, 0);
      expect(report.danglingFingerprints, [Fingerprint('cafebabe')]);
      expect(report.didWork, isTrue);
      // Still present — a dangler (possibly a transient lock) is never dropped.
      expect(await m.index.get(Fingerprint('cafebabe')), isNotNull);
    });

    test('a legacy bare-fingerprint key is surfaced, never mis-healed', () async {
      final kv = FakeSecureKeyValueStore();
      final m = _make(kv);
      // A pre-`seed_` legacy key: present in the store, not under the package's
      // scheme. It must NOT count as a healable orphan (the package can't read
      // `seed_<fp>` for it) and must NOT be dropped — it is surfaced for the
      // app's migration to re-key.
      await m.repo.reconcile(); // no-op baseline
      final store = FssSecretStoreAdapter(kv, initialRetryDelay: Duration.zero);
      await store.store('a1b2c3d4', Uint8List.fromList([1, 2, 3]));

      final report = _report(await m.repo.reconcile());
      expect(report.healed, 0);
      expect(report.failures, isEmpty);
      expect(report.legacyKeys, contains('a1b2c3d4'));
      expect(report.didWork, isTrue);
    });

    test('a MIS-KEYED orphan (blob decodes to a different fp) is collected, '
        'never crashes or phantom-heals', () async {
      final kv = FakeSecureKeyValueStore();
      final m = _make(kv);
      // A valid zoo mnemonic blob stored under the WRONG key (seed_deadbeef).
      // Reconcile treats deadbeef as an orphan, but the heal must detect that the
      // content decodes to a DIFFERENT fingerprint and refuse — collecting it as
      // a failure (a catchable MalformedSecretException → InvalidMnemonicFailure),
      // NOT crashing (a dart:core Error would escape the guard) and NOT indexing a
      // phantom entry under the real fingerprint.
      final store = FssSecretStoreAdapter(kv, initialRetryDelay: Duration.zero);
      final blob = Uint8List.fromList(utf8.encode(jsonEncode({
        'kind': 'mnemonic',
        'words': _zooWords,
        'language': 'english',
      })));
      await store.store(SecretStoreKeys.seedKey('deadbeef'), blob);

      final report = _report(await m.repo.reconcile()); // Ok, not a crash
      expect(report.healed, 0);
      expect(report.failures, hasLength(1));
      expect(report.failures.single.fingerprint, Fingerprint('deadbeef'));
      // No phantom index entry under the real zoo fingerprint (3f635a63).
      expect(await m.index.get(Fingerprint('3f635a63')), isNull);
    });

    test('a locked keychain defers cleanly (Err), never crashes', () async {
      final repo = SecretLifecycleAdapter(
        store: _LockedStore(),
        index: _FakeSeedIndex(),
      );
      final r = await repo.reconcile();
      expect(r, isA<Err<ReconcileReport, SecretsFailure>>());
      expect((r as Err).failure, isA<KeychainLockedFailure>());
    });
  });
}
