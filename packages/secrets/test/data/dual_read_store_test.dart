import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/dual_read_store.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/adapters/oubliette_secret_store_adapter.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/data/migration/secret_migrator.dart';
import 'package:secrets/src/domain/ports/secret_index_port.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';
import 'package:secrets/src/domain/value_objects/secret_info.dart';

import 'fake_oubliette.dart';
import 'fake_secure_key_value_store.dart';

/// In-memory [SecretIndexPort] keyed by fingerprint hex.
class _FakeIndex implements SecretIndexPort {
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

SecretInfo _info(String hex) => SecretInfo(
      fingerprint: Fingerprint(hex),
      kind: SecretKind.mnemonic,
      wordCount: 12,
      hasPassphrase: false,
      language: 'english',
    );

void main() {
  late FakeOubliette o;
  late OublietteSecretStoreAdapter hw;
  late FakeSecureKeyValueStore kv;
  late FssSecretStoreAdapter fss;
  late DualReadStore dual;

  setUp(() {
    o = FakeOubliette();
    hw = OublietteSecretStoreAdapter(o);
    kv = FakeSecureKeyValueStore();
    fss = FssSecretStoreAdapter(kv, initialRetryDelay: Duration.zero);
    dual = DualReadStore(hardware: hw, fallback: fss);
  });

  Uint8List b(List<int> v) => Uint8List.fromList(v);

  group('read precedence', () {
    test('a hardware-resident key reads from hardware', () async {
      await hw.store('seed_a', b([1, 1]));
      await fss.store('seed_a', b([9, 9])); // stale FSS copy, must be ignored
      final got = await dual.useAndForget('seed_a', (x) async => x.toList());
      expect(got, [1, 1]);
    });

    test('a key only in FSS falls back to FSS', () async {
      await fss.store('seed_b', b([7, 7]));
      final got = await dual.useAndForget('seed_b', (x) async => x.toList());
      expect(got, [7, 7]);
    });

    test('useAndForget does NOT re-run the closure on FSS when it threw '
        'SecretNotFoundException AFTER receiving hardware bytes', () async {
      await hw.store('seed_c', b([5]));
      var calls = 0;
      await expectLater(
        () => dual.useAndForget('seed_c', (x) async {
          calls++;
          throw const SecretNotFoundException('seed_c');
        }),
        throwsA(isA<SecretNotFoundException>()),
      );
      expect(calls, 1); // the guard rethrew; no double invocation on FSS
    });
  });

  group('writes', () {
    test('store goes to hardware only', () async {
      await dual.store('seed_d', b([3]));
      expect(await hw.exists('seed_d'), isTrue);
      expect(await fss.exists('seed_d'), isFalse);
    });

    test('exists is the union of both backends', () async {
      await hw.store('in_hw', b([1]));
      await fss.store('in_fss', b([2]));
      expect(await dual.exists('in_hw'), isTrue);
      expect(await dual.exists('in_fss'), isTrue);
      expect(await dual.exists('nowhere'), isFalse);
    });

    test('trash removes from both backends', () async {
      await hw.store('seed_e', b([1]));
      await fss.store('seed_e', b([1]));
      await dual.trash('seed_e');
      expect(await hw.exists('seed_e'), isFalse);
      expect(await fss.exists('seed_e'), isFalse);
    });

    test('keys is the de-duplicated union', () async {
      await hw.store('shared', b([1]));
      await fss.store('shared', b([1]));
      await fss.store('fss_only', b([2]));
      final keys = await dual.keys();
      expect(keys.toSet(), {'shared', 'fss_only'});
      expect(keys.length, 2); // de-duplicated
    });
  });

  group('migratePending', () {
    test('copies FSS-only indexed seeds into hardware, retaining FSS',
        () async {
      const hex = 'deadbeef';
      final key = SecretStoreKeys.seedKey(hex);
      await fss.store(key, b([4, 5, 6]));
      final index = _FakeIndex()..upsert(_info(hex));

      final report = await dual.migratePending(index);

      expect(report.migrated, 1);
      expect(report.skipped, 0);
      expect(report.complete, isTrue);
      expect(await hw.exists(key), isTrue); // now in hardware
      expect(await fss.exists(key), isTrue); // FSS copy retained (safety net)
    });

    test('is idempotent: a re-run skips an already-migrated seed', () async {
      const hex = 'deadbeef';
      final key = SecretStoreKeys.seedKey(hex);
      await fss.store(key, b([4, 5, 6]));
      final index = _FakeIndex()..upsert(_info(hex));

      await dual.migratePending(index);
      final second = await dual.migratePending(index);

      expect(second.migrated, 0);
      expect(second.skipped, 1);
      expect(second.didWork, isFalse); // a settled device stays silent
    });

    test('a dangling index entry (in neither store) is reported, not thrown',
        () async {
      final index = _FakeIndex()..upsert(_info('cafebabe'));
      final report = await dual.migratePending(index);
      expect(report.migrated, 0);
      expect(report.failures, hasLength(1));
      expect(report.failures.single.fingerprint.hex, 'cafebabe');
      expect(report.complete, isFalse);
    });

    test('an FSS seed key ABSENT from the index blocks complete (census)',
        () async {
      // An un-healed orphan: material lives in FSS but the index never saw it.
      // A completeness-gated FSS removal would destroy it, so complete must be
      // false and the orphan reported.
      await fss.store(SecretStoreKeys.seedKey('abcd1234'), b([1, 2, 3]));
      final report = await dual.migratePending(_FakeIndex()); // empty index
      expect(report.migrated, 0);
      expect(report.complete, isFalse);
      expect(
        report.failures.map((f) => f.errorType),
        contains('fss_orphan_not_indexed'),
      );
    });

    test('a delete racing the pass (index removed) does NOT resurrect the seed',
        () async {
      const hex = 'deadbeef';
      final key = SecretStoreKeys.seedKey(hex);
      await fss.store(key, b([4, 5, 6]));
      // index.get() returns null — a delete whose index.remove already ran.
      final report = await dual.migratePending(_RacingDeleteIndex(_info(hex)));
      expect(report.migrated, 0);
      expect(await hw.exists(key), isFalse);
    });

    test('a delete racing the pass (FSS trashed, index still present) does NOT '
        'resurrect the seed', () async {
      // The REAL interleaving: delete trashes the FSS store BEFORE removing the
      // index, so the migrator reads the FSS bytes, then the FSS copy vanishes
      // while the index snapshot still lists the seed. The FSS-existence
      // re-check must catch it and refuse to write hardware.
      const hex = 'deadbeef';
      final key = SecretStoreKeys.seedKey(hex);
      final racingFss = _ReadOnceThenGoneFss(key, b([4, 5, 6]));
      final migrator = SecretMigrator(
        hardware: hw,
        fallback: racingFss,
        index: _FakeIndex()..upsert(_info(hex)), // index still has it
      );
      final report = await migrator.run();
      expect(report.migrated, 0);
      expect(await hw.exists(key), isFalse); // no resurrection
    });

    test('a WRONG hardware copy shadowing a good FSS copy is detected, trashed, '
        'and re-migrated (skip path byte-verifies)', () async {
      const hex = 'deadbeef';
      final key = SecretStoreKeys.seedKey(hex);
      await fss.store(key, b([4, 5, 6])); // the GOOD copy
      await hw.store(key, b([9, 9, 9])); // a corrupt/wrong HW copy
      final index = _FakeIndex()..upsert(_info(hex));

      final report = await dual.migratePending(index);

      // Presence-only would have counted this `skipped` (poisoning `complete`);
      // the byte-verify catches the mismatch, trashes it, and re-migrates.
      expect(report.migrated, 1);
      expect(report.complete, isTrue);
      final got = await hw.useAndForget(key, (x) async => x.toList());
      expect(got, [4, 5, 6]); // hardware now holds the GOOD bytes
    });

    test('a backend that persists CORRUPT bytes fails verify, trashes the copy, '
        'and keeps complete=false', () async {
      const hex = 'deadbeef';
      final key = SecretStoreKeys.seedKey(hex);
      await fss.store(key, b([4, 5, 6]));
      final corrupting = _CorruptingHwStore();
      final migrator = SecretMigrator(
        hardware: corrupting,
        fallback: fss,
        index: _FakeIndex()..upsert(_info(hex)),
      );

      final report = await migrator.run();

      expect(report.migrated, 0);
      expect(report.complete, isFalse); // never authorizes FSS removal
      expect(report.failures.single.errorType, 'verify_mismatch');
      expect(corrupting.trashed, contains(key)); // bad copy removed for re-run
    });
  });
}

/// FSS whose `useAndForget` serves the seed ONCE, then reports it gone (models a
/// delete trashing the FSS copy between the migrator's read and its store).
class _ReadOnceThenGoneFss implements SecretStorePort {
  _ReadOnceThenGoneFss(this._key, this._bytes);
  final String _key;
  final Uint8List _bytes;
  bool _read = false;
  @override
  Future<void> init() async {}
  @override
  StoreCapabilities capabilities() => const StoreCapabilities(
      hardwareBacked: false, thisDeviceOnly: true, syncable: false);
  @override
  Future<R> useAndForget<R>(String key, Future<R> Function(Uint8List) use) async {
    _read = true;
    return use(Uint8List.fromList(_bytes));
  }
  @override
  Future<bool> exists(String key) async => !_read; // gone after the read
  @override
  Future<void> store(String key, Uint8List value) async {}
  @override
  Future<void> trash(String key) async {}
  @override
  Future<void> purge() async {}
  @override
  Future<List<String>> keys() async => _read ? [] : [_key];
}

/// A hardware store that ACKS the write but persists DIFFERENT bytes — the
/// OEM-keystore failure class the byte-verify exists to catch.
class _CorruptingHwStore implements SecretStorePort {
  final Map<String, Uint8List> _m = {};
  final List<String> trashed = [];
  @override
  Future<void> init() async {}
  @override
  StoreCapabilities capabilities() => const StoreCapabilities(
      hardwareBacked: true, thisDeviceOnly: true, syncable: false);
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

/// An index whose `all()` still lists the seed (the migrator's snapshot) but
/// whose `get()` returns null — a delete that completed mid-pass.
class _RacingDeleteIndex implements SecretIndexPort {
  _RacingDeleteIndex(this._snapshot);
  final SecretInfo _snapshot;
  @override
  Future<List<SecretInfo>> all() async => [_snapshot];
  @override
  Future<SecretInfo?> get(Fingerprint fp) async => null; // deleted meanwhile
  @override
  Future<void> remove(Fingerprint fp) async {}
  @override
  Future<void> upsert(SecretInfo info) async {}
}
