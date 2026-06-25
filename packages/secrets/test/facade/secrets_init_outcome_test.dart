import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oubliette/oubliette.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/src/data/adapters/dual_read_store.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/adapters/oubliette_secret_store_adapter.dart';

import '../data/fake_oubliette.dart';
import '../data/fake_secure_key_value_store.dart';

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
  tearDown(Secrets.reset);

  group('probeBackend', () {
    test('a healthy device → oubliette, no error', () async {
      final r = await Secrets.probeBackend(oubliette: FakeOubliette());
      expect(r.outcome, SecretsBackendOutcome.oubliette);
      expect(r.probeError, isNull);
    });

    test('a locked device → fssDeferred (re-probe later), carries the error',
        () async {
      final r =
          await Secrets.probeBackend(oubliette: FakeOubliette()..locked = true);
      expect(r.outcome, SecretsBackendOutcome.fssDeferred);
      expect(r.probeError, isNotNull);
    });

    test('a keyring service that is down → fssDeferred (recoverable)', () async {
      final r = await Secrets.probeBackend(
          oubliette: FakeOubliette()..backendUnavailable = true);
      expect(r.outcome, SecretsBackendOutcome.fssDeferred);
    });

    test('an invalidated key → fssIncompatible (structural, persist FSS)',
        () async {
      final r = await Secrets.probeBackend(
          oubliette: FakeOubliette()..keyInvalidated = true);
      expect(r.outcome, SecretsBackendOutcome.fssIncompatible);
      expect(r.probeError, isNotNull);
    });

    test('a trailing cleanup-trash failure does NOT downgrade a capable device',
        () async {
      // The round-trip (init/store/read) all succeed; only the probe's final
      // best-effort trash trips a lock. Outcome must stay `oubliette`, not be
      // downgraded to fssDeferred by the cleanup.
      final fake = FakeOubliette()
        ..throwOnTrash = const AuthenticationFailedException()
        ..trashSucceedsFor = 1; // stale-clear (#1) ok; cleanup (#2) throws
      final r = await Secrets.probeBackend(oubliette: fake);
      expect(r.outcome, SecretsBackendOutcome.oubliette);
      expect(r.probeError, isNull);
    });
  });

  group('init with an injected store seam', () {
    test('reports the oubliette outcome and wires a working facade', () async {
      final r = await Secrets.init(
        index: _FakeIndex(),
        store: OublietteSecretStoreAdapter(FakeOubliette()),
      );
      expect(r.outcome, SecretsBackendOutcome.oubliette);

      // The wired graph round-trips through the injected store.
      const words = <String>[
        'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'abandon', //
        'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'about',
      ];
      final imported = await Secrets.importMnemonic(words);
      expect(imported, isA<Ok<MnemonicSecret, SecretsFailure>>());
    });

    test('migrateToHardware is null for a non-dual (FSS-only) store', () async {
      await Secrets.init(
        index: _FakeIndex(),
        store: OublietteSecretStoreAdapter(FakeOubliette()),
      );
      expect(await Secrets.migrateToHardware(), isNull);
    });

    test('reset clears the in-flight guard so a later init re-runs', () async {
      await Secrets.init(
        index: _FakeIndex(),
        store: OublietteSecretStoreAdapter(FakeOubliette()),
      );
      Secrets.reset();
      // Using the facade before re-init must throw, proving reset dropped the
      // wired graph (not a stale instance from the first init).
      expect(() => Secrets.list(), throwsA(isA<StateError>()));

      final again = await Secrets.init(
        index: _FakeIndex(),
        store: OublietteSecretStoreAdapter(FakeOubliette()),
      );
      expect(again.outcome, SecretsBackendOutcome.oubliette);
    });
  });

  group('migrateToHardware concurrency guard', () {
    test('overlapping calls share one pass — no spurious duplicate failure',
        () async {
      // A DualReadStore with one FSS-only seed to migrate. Without the in-flight
      // guard, a second concurrent pass would re-store the same key and trip
      // oubliette's write-once StateError, polluting the census with a fake
      // failure. With the guard, both callers share one pass.
      final fss = FssSecretStoreAdapter(FakeSecureKeyValueStore(),
          initialRetryDelay: Duration.zero);
      final hw = OublietteSecretStoreAdapter(FakeOubliette());
      const hex = 'deadbeef';
      await fss.store(
          SecretStoreKeys.seedKey(hex), Uint8List.fromList([1, 2, 3]));
      await Secrets.init(
        index: _FakeIndex()..upsert(_info(hex)),
        store: DualReadStore(hardware: hw, fallback: fss),
      );

      final results = await Future.wait([
        Secrets.migrateToHardware(),
        Secrets.migrateToHardware(),
      ]);

      expect(identical(results[0], results[1]), isTrue); // one shared pass
      expect(results[0]!.migrated, 1);
      expect(results[0]!.failures, isEmpty); // no spurious AlreadyExists
    });
  });
}
