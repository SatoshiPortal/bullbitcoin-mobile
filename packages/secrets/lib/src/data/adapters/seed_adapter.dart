import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/adapters/secret_guard.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/data/models/mnemonic.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';
import 'package:secrets/src/domain/ports/seed_index_port.dart';
import 'package:secrets/src/domain/ports/seed_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/mnemonic_length.dart';
import 'package:secrets/src/domain/value_objects/seed_info.dart';

/// The seed-lifecycle adapter — the single public-edge conversion-to-Result
/// boundary for storing/indexing mnemonics. Foreign exceptions are converted
/// ONCE via [SecretGuard]; `dart:core` `Error`s (programmer bugs) crash.
class SeedAdapter implements SeedPort {
  SeedAdapter({required SecretStorePort store, required SeedIndexPort index})
      : _store = store,
        _index = index,
        _guard = SecretGuard(store);

  final SecretStorePort _store;
  final SeedIndexPort _index;
  final SecretGuard _guard;

  String _key(Fingerprint fp) => SecretStoreKeys.seedKey(fp.hex);

  /// Resolves a user-supplied language on the IMPORT entry points. Unlike the
  /// storage-DECODE path (which stays forward-compatible and falls back to
  /// English), import REJECTS an unknown language rather than silently
  /// misinterpreting the words. Returns null when unrecognized.
  static bip39.Language? _lang(String name) {
    for (final l in bip39.Language.values) {
      if (l.name == name) return l;
    }
    return null;
  }

  SecretsFailure _err(String log) => SecretsUnexpectedFailure(log);

  /// Persists a freshly-built mnemonic: duplicate-checks the fingerprint,
  /// stores, indexes, returns the fingerprint.
  Future<Result<Fingerprint, SecretsFailure>> _persist(Mnemonic m) async {
    final fp = m.fingerprint; // may throw MnemonicException → caught by _guard
    if (await _store.exists(_key(fp))) {
      return Err(DuplicateSeedFailure(fp));
    }
    try {
      await _store.store(_key(fp), m.toStorageBytes());
    } on SecretAlreadyExistsException {
      // A concurrent import won the race between exists() and store().
      return Err(DuplicateSeedFailure(fp));
    }
    await _index.upsert(m.toInfo(createdAt: DateTime.now()));
    return Ok(fp);
  }

  @override
  Future<Result<Fingerprint, SecretsFailure>> importMnemonic({
    required List<String> words,
    String? passphrase,
    String language = 'english',
  }) =>
      _guard.run(
        () {
          final lang = _lang(language);
          if (lang == null) {
            return Future.value(Err<Fingerprint, SecretsFailure>(
                InvalidMnemonicFailure('unknown language: $language')));
          }
          return _persist(
            Mnemonic(words: words, passphrase: passphrase, language: lang),
          );
        },
        onError: _err,
      );

  @override
  Future<Result<Fingerprint, SecretsFailure>> generateMnemonic({
    MnemonicLength length = MnemonicLength.words12,
  }) =>
      _guard.run(() {
        final m = bip39.Mnemonic.generate(
          bip39.Language.english,
          length: length == MnemonicLength.words12
              ? bip39.MnemonicLength.words12
              : bip39.MnemonicLength.words24,
        );
        return _persist(Mnemonic(words: m.words));
      }, onError: _err);

  @override
  Future<Result<void, SecretsFailure>> delete(Fingerprint fp) =>
      _guard.run(() async {
        await _store.trash(_key(fp));
        await _index.remove(fp);
        return const Ok<void, SecretsFailure>(null);
      }, onError: _err);

  @override
  Future<Result<bool, SecretsFailure>> exists(Fingerprint fp) =>
      _guard.run(() async => Ok(await _store.exists(_key(fp))), onError: _err);

  @override
  Future<Result<List<SeedInfo>, SecretsFailure>> listSeeds() =>
      _guard.run(() async => Ok(await _index.all()), onError: _err);

  @override
  Future<Result<SeedInfo?, SecretsFailure>> getInfo(Fingerprint fp) =>
      _guard.run(() async => Ok(await _index.get(fp)), onError: _err);

  @override
  Future<Result<Fingerprint, SecretsFailure>> fingerprintOf({
    required List<String> words,
    String? passphrase,
    String language = 'english',
  }) =>
      _guard.run(
        () async {
          final lang = _lang(language);
          if (lang == null) {
            return Err<Fingerprint, SecretsFailure>(
                InvalidMnemonicFailure('unknown language: $language'));
          }
          return Ok(
            Mnemonic(words: words, passphrase: passphrase, language: lang)
                .fingerprint,
          );
        },
        onError: _err,
      );
}
