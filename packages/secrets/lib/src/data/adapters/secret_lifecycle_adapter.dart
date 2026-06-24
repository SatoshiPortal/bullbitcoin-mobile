import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/adapters/secret_guard.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/data/models/mnemonic.dart';
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

  SecretsFailure _err(String log) => SecretsUnexpectedFailure(log);

  /// Persists a freshly-built mnemonic: duplicate-checks the fingerprint,
  /// stores, indexes, returns the fingerprint.
  Future<Result<Fingerprint, SecretsFailure>> _persist(Mnemonic m) async {
    final fp = m.fingerprint; // may throw MnemonicException → caught by _guard
    if (await _store.exists(_key(fp))) {
      return Err(DuplicateSecretFailure(fp));
    }
    try {
      await _store.store(_key(fp), m.toStorageBytes());
    } on SecretAlreadyExistsException {
      // A concurrent import won the race between exists() and store().
      return Err(DuplicateSecretFailure(fp));
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
        onError: _err,
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
  Future<Result<List<SecretInfo>, SecretsFailure>> listSeeds() =>
      _guard.run(() async => Ok(await _index.all()), onError: _err);

  @override
  Future<Result<SecretInfo?, SecretsFailure>> getInfo(Fingerprint fp) =>
      _guard.run(() async => Ok(await _index.get(fp)), onError: _err);

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
        onError: _err,
      );
}
