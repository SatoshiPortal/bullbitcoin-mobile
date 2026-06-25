import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/dual_read_store.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/adapters/oubliette_secret_store_adapter.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/domain/ports/secret_index_port.dart';
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
  });
}
