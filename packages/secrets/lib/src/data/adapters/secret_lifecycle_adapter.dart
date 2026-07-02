import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/adapters/secret_guard.dart';
import 'package:secrets/src/data/datasources/malformed_secret_exception.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/data/migration/reconcile_report.dart';
import 'package:secrets/src/data/models/mnemonic.dart';
import 'package:secrets/src/data/seed_reconciler.dart';
import 'package:secrets/src/domain/ports/secret_index_port.dart';
import 'package:secrets/src/domain/ports/secret_lifecycle_port.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/mnemonic_language.dart';
import 'package:secrets/src/domain/value_objects/mnemonic_length.dart';
import 'package:secrets/src/domain/value_objects/secret_info.dart';

/// The secret-lifecycle adapter — the single public-edge conversion-to-Result
/// boundary for storing/indexing mnemonics. Foreign exceptions are converted
/// ONCE via [SecretGuard]; `dart:core` `Error`s (programmer bugs) crash.
class SecretLifecycleAdapter implements SecretLifecyclePort {
  SecretLifecycleAdapter({required SecretStorePort store, required this._index})
      : _store = store,
        _guard = SecretGuard(store);

  final SecretStorePort _store;
  final SecretIndexPort _index;
  final SecretGuard _guard;

  String _key(Fingerprint fp) => SecretStoreKeys.seedKey(fp.hex);

  /// Persists a freshly-built mnemonic: duplicate-checks the fingerprint,
  /// stores, indexes, returns the fingerprint.
  Future<Result<Fingerprint, SecretsFailure>> _persist(Mnemonic m) async {
    final fp = m.fingerprint; // may throw MnemonicException → caught by _guard
    if (await _store.exists(_key(fp))) {
      return Err(DuplicateSecretFailure(fp));
    }
    // Zero the JSON-encoded write buffer after the store, matching the package's
    // own hygiene standard (the migrator and FSS reads zero their buffers; the
    // main write site must too). The FSS adapter base64-copies before persisting,
    // so this buffer is ours to wipe.
    final bytes = m.toStorageBytes();
    try {
      await _store.store(_key(fp), bytes);
    } on SecretAlreadyExistsException {
      // A concurrent import won the race between exists() and store().
      return Err(DuplicateSecretFailure(fp));
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
    await _index.upsert(m.toInfo(createdAt: DateTime.now()));
    return Ok(fp);
  }

  @override
  Future<Result<Fingerprint, SecretsFailure>> importMnemonic({
    required List<String> words,
    String? passphrase,
    MnemonicLanguage language = MnemonicLanguage.english,
  }) =>
      _guard.run(
        () => _persist(
          Mnemonic(
            words: words,
            passphrase: passphrase,
            language: language.asBip39,
          ),
        ),
        onError: SecretsUnexpectedFailure.new,
      );

  @override
  Future<Result<Fingerprint, SecretsFailure>> generateMnemonic({
    MnemonicLength length = MnemonicLength.words12,
  }) =>
      _guard.run(() {
        final m = bip39.Mnemonic.generate(
          bip39.Language.english,
          length: length.asBip39,
        );
        return _persist(Mnemonic(words: m.words));
      }, onError: SecretsUnexpectedFailure.new);

  @override
  Future<Result<void, SecretsFailure>> delete(Fingerprint fp) =>
      _guard.run(() async {
        await _store.trash(_key(fp));
        await _index.remove(fp);
        return const Ok<void, SecretsFailure>(null);
      }, onError: SecretsUnexpectedFailure.new);

  @override
  Future<Result<bool, SecretsFailure>> exists(Fingerprint fp) =>
      _guard.run(() async => Ok(await _store.exists(_key(fp))), onError: SecretsUnexpectedFailure.new);

  @override
  Future<Result<List<SecretInfo>, SecretsFailure>> listSeeds() =>
      _guard.run(() async => Ok(await _index.all()), onError: SecretsUnexpectedFailure.new);

  @override
  Future<Result<SecretInfo?, SecretsFailure>> getInfo(Fingerprint fp) =>
      _guard.run(() async => Ok(await _index.get(fp)), onError: SecretsUnexpectedFailure.new);

  @override
  Future<Result<Fingerprint, SecretsFailure>> fingerprintOf({
    required List<String> words,
    String? passphrase,
    MnemonicLanguage language = MnemonicLanguage.english,
  }) =>
      _guard.run(
        () async => Ok(
          Mnemonic(
            words: words,
            passphrase: passphrase,
            language: language.asBip39,
          ).fingerprint,
        ),
        onError: SecretsUnexpectedFailure.new,
      );

  @override
  Future<Result<ReconcileReport, SecretsFailure>> reconcile() =>
      _guard.run(() async {
        final drift = await reconcileSeeds(index: _index, store: _store);
        var healed = 0;
        final failures = <({Fingerprint fingerprint, String errorType})>[];
        for (final fp in drift.orphanSeedFingerprints) {
          // Re-index one orphan: read it through the guard (the sanctioned
          // reader — no new raw-read site) and upsert its non-secret info.
          // createdAt is unknown for a healed orphan (the original index write
          // is exactly what failed), so it stays null.
          final r = await _healOrphan(fp);
          switch (r) {
            case Ok():
              healed++;
            case Err(:final failure):
              // Collected, never thrown: one bad/locked orphan (a legacy
              // bare-fingerprint key, a malformed blob) must not abort the rest;
              // only the failure's runtime *type* is recorded, never secret text.
              failures.add(
                (fingerprint: fp, errorType: failure.runtimeType.toString()),
              );
          }
        }
        return Ok(
          ReconcileReport(
            healed: healed,
            danglingFingerprints: drift.danglingIndexFingerprints,
            legacyKeys: drift.legacyStoreKeys,
            malformedKeys: drift.malformedKeys,
            failures: failures,
          ),
        );
      }, onError: SecretsUnexpectedFailure.new);

  Future<Result<void, SecretsFailure>> _healOrphan(Fingerprint fp) =>
      _guard.read<void>(fp, (m) async {
        // Assert the content-derived fingerprint matches the storage key. A
        // mis-keyed blob (stored under seed_<fpA> but decoding to fpB) would
        // otherwise be "healed" into a phantom fpB index entry that re-heals and
        // reports success every startup, while fpA stays orphaned forever. Throw
        // a MalformedSecretException (a catchable Exception, NOT a dart:core
        // Error that would escape SecretGuard and crash reconcile) so it is
        // COLLECTED as a per-orphan failure — surfaced, never silently healed.
        if (m.fingerprint != fp) {
          throw MalformedSecretException(
              'orphan key mismatch: stored under ${fp.hex} but decodes to '
              '${m.fingerprint.hex}');
        }
        await _index.upsert(m.toInfo());
        return const Ok<void, SecretsFailure>(null);
      }, onError: SecretsUnexpectedFailure.new);
}
