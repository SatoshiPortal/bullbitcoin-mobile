import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/dual_read_store.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/adapters/oubliette_secret_store_adapter.dart';
import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/data/migration/secret_migrator.dart';
import 'package:secrets/src/domain/ports/secret_index_port.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';
import 'package:secrets/src/domain/value_objects/secret_info.dart';

import 'fake_oubliette.dart';
import 'fake_secure_key_value_store.dart';

// A valid BIP39 mnemonic whose master fingerprint is `3f635a63` (see
// reconcile_test.dart). Its storage blob decodes to that fingerprint, so the
// migrator's High-#1 fingerprint arbitration can identify it as authentic.
const _zooWords = [
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'zoo', //
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'wrong',
];
const _zooFpHex = '3f635a63';

/// The package's native storage encoding for a mnemonic (matches
/// `Mnemonic.toStorageBytes`), built directly so the test needs no internal ctor.
Uint8List _mnemonicBlob(List<String> words) => Uint8List.fromList(
      utf8.encode(jsonEncode(
          {'kind': 'mnemonic', 'words': words, 'language': 'english'})),
    );

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

    test('a WRONG hardware copy shadowing a FINGERPRINT-VERIFIED FSS copy is '
        'trashed and re-migrated (skip path arbitrates by fingerprint)',
        () async {
      final key = SecretStoreKeys.seedKey(_zooFpHex);
      await fss.store(key, _mnemonicBlob(_zooWords)); // GOOD (decodes to key fp)
      await hw.store(key, b([9, 9, 9])); // corrupt HW copy (does NOT decode)
      final index = _FakeIndex()..upsert(_info(_zooFpHex));

      final report = await dual.migratePending(index);

      // HW is definitively corrupt AND FSS fingerprint-matches the key → HW is
      // trashed and re-migrated from the verified FSS copy.
      expect(report.migrated, 1);
      expect(report.complete, isTrue);
      final got = await hw.useAndForget(key, (x) async => x.toList());
      expect(got, _mnemonicBlob(_zooWords).toList()); // HW now holds the good blob
    });

    test('High #1: a FINGERPRINT-VERIFIED hardware copy is NEVER destroyed by a '
        'corrupt FSS copy (migration does not trust the weaker store)', () async {
      final key = SecretStoreKeys.seedKey(_zooFpHex);
      await hw.store(key, _mnemonicBlob(_zooWords)); // GOOD hardware copy
      await fss.store(key, b([9, 9, 9])); // CORRUPT FSS copy (bit-rot / re-encode)
      final index = _FakeIndex()..upsert(_info(_zooFpHex));

      final report = await dual.migratePending(index);

      // The bytes differ, but HW fingerprint-matches the key and FSS does not —
      // so HW is authentic and kept as-is (skipped), NOT overwritten by the
      // corrupt FSS bytes. This is the exact corruption-trust bug High #1 fixes.
      expect(report.skipped, 1);
      expect(report.migrated, 0);
      final got = await hw.useAndForget(key, (x) async => x.toList());
      expect(got, _mnemonicBlob(_zooWords).toList()); // untouched — still good
    });

    test('High #1: when NEITHER copy fingerprint-matches, DESTROY NOTHING and '
        'keep complete=false (unverifiable)', () async {
      final key = SecretStoreKeys.seedKey(_zooFpHex);
      await hw.store(key, b([9, 9, 9])); // corrupt
      await fss.store(key, b([7, 7, 7])); // also corrupt / different
      final index = _FakeIndex()..upsert(_info(_zooFpHex));

      final report = await dual.migratePending(index);

      expect(report.migrated, 0);
      expect(report.complete, isFalse); // never authorizes FSS removal
      expect(
        report.failures.map((f) => f.errorType),
        contains('hw_fss_unverifiable'),
      );
      // BOTH copies survive — we cannot tell which (if either) is real.
      expect(await hw.exists(key), isTrue);
      expect(await fss.exists(key), isTrue);
    });

    test('policy: a hardware read FAILURE (not a miss) does NOT fall back to FSS',
        () async {
      // DualReadStore falls back to FSS only on a hardware MISS. A hardware read
      // that FAILS (locked / key-invalidated) must surface as a typed failure so
      // the app can telemeter degradation — silently masking it with the FSS
      // copy would inflate the compatibility census (dual_read_store §2.3). A
      // well-meaning "just read FSS on any HW error" regression would flip this.
      final failingHw = _FailingReadHw();
      final recordingFss = _RecordingFallback(b([1, 2, 3]));
      final d = DualReadStore(hardware: failingHw, fallback: recordingFss);

      await expectLater(
        () => d.useAndForget('seed_x', (x) async => x.toList()),
        throwsA(isA<KeychainLockedException>()),
      );
      expect(failingHw.readAttempts, 1); // hardware WAS tried
      expect(recordingFss.reads, 0); // FSS was NOT consulted on a HW failure
    });

    test('FSS locked during the HW-vs-FSS verify records a failure WITHOUT '
        'trashing the hardware copy (locked ≠ corrupt)', () async {
      // HW already holds the seed; the verify reads FSS to byte-compare, but FSS
      // is locked. A lock is transient — it must NOT be mistaken for a corrupt
      // HW copy and trigger a trash. The pass records a failure (so complete is
      // false) and leaves the hardware copy intact for the next run.
      final key = SecretStoreKeys.seedKey(_zooFpHex);
      await hw.store(key, _mnemonicBlob(_zooWords));
      final migrator = SecretMigrator(
        hardware: hw,
        fallback: _LockedReadFss(),
        index: _FakeIndex()..upsert(_info(_zooFpHex)),
      );

      final report = await migrator.run();

      expect(report.migrated, 0);
      expect(report.skipped, 0);
      expect(report.complete, isFalse); // a locked verify is not "clean"
      expect(await hw.exists(key), isTrue); // HW copy survives the transient lock
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

/// A hardware store whose read always FAILS (locked) — models a degraded/locked
/// keystore, distinct from a MISS (SecretNotFoundException).
class _FailingReadHw implements SecretStorePort {
  int readAttempts = 0;
  @override
  Future<void> init() async {}
  @override
  StoreCapabilities capabilities() => const StoreCapabilities(
      hardwareBacked: true, thisDeviceOnly: true, syncable: false);
  @override
  Future<R> useAndForget<R>(String key, Future<R> Function(Uint8List) use) async {
    readAttempts++;
    throw const KeychainLockedException();
  }
  @override
  Future<bool> exists(String key) async => true;
  @override
  Future<void> store(String key, Uint8List value) async {}
  @override
  Future<void> trash(String key) async {}
  @override
  Future<void> purge() async {}
  @override
  Future<List<String>> keys() async => const [];
}

/// An FSS store whose read is LOCKED (throws) but which is otherwise present —
/// models a keychain locked during the migrator's HW-vs-FSS verify.
class _LockedReadFss implements SecretStorePort {
  @override
  Future<void> init() async {}
  @override
  StoreCapabilities capabilities() => const StoreCapabilities(
      hardwareBacked: false, thisDeviceOnly: true, syncable: false);
  @override
  Future<R> useAndForget<R>(String key, Future<R> Function(Uint8List) use) async {
    throw const KeychainLockedException();
  }
  @override
  Future<bool> exists(String key) async => true;
  @override
  Future<void> store(String key, Uint8List value) async {}
  @override
  Future<void> trash(String key) async {}
  @override
  Future<void> purge() async {}
  @override
  Future<List<String>> keys() async => const []; // census clean (not locked)
}

/// A fallback store that COUNTS how many times its read is invoked, so a test can
/// assert it was (not) consulted.
class _RecordingFallback implements SecretStorePort {
  _RecordingFallback(this._bytes);
  final Uint8List _bytes;
  int reads = 0;
  @override
  Future<void> init() async {}
  @override
  StoreCapabilities capabilities() => const StoreCapabilities(
      hardwareBacked: false, thisDeviceOnly: true, syncable: false);
  @override
  Future<R> useAndForget<R>(String key, Future<R> Function(Uint8List) use) async {
    reads++;
    return use(Uint8List.fromList(_bytes));
  }
  @override
  Future<bool> exists(String key) async => true;
  @override
  Future<void> store(String key, Uint8List value) async {}
  @override
  Future<void> trash(String key) async {}
  @override
  Future<void> purge() async {}
  @override
  Future<List<String>> keys() async => const [];
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
