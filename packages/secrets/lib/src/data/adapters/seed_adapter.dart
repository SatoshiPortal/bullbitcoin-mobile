import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/datasources/fss_secret_store.dart';
import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/data/models/seed_secret.dart';
import 'package:secrets/src/domain/log_sanitizer.dart';
import 'package:secrets/src/domain/seed_index.dart';
import 'package:secrets/src/domain/seed_repository.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/mnemonic_length.dart';
import 'package:secrets/src/domain/value_objects/seed_info.dart';
import 'package:secrets/src/storage/secret_store.dart';

/// The single public-edge conversion-to-Result boundary for the seed lifecycle.
/// Foreign exceptions are caught here ONCE, sanitized, and mapped to a
/// [SecretsFailure]; `dart:core` `Error`s (programmer bugs) are left to crash.
class SeedRepositoryImpl implements SeedRepository {
  SeedRepositoryImpl({required SecretStore store, required SeedIndex index})
      : _store = store,
        _index = index;

  final SecretStore _store;
  final SeedIndex _index;

  String _key(Fingerprint fp) => SecretStoreKeys.seedKey(fp.hex);

  /// Persists a freshly-built secret: duplicate-checks the fingerprint, stores,
  /// indexes, returns the fingerprint.
  Future<Result<Fingerprint, SecretsFailure>> _persist(
      SeedSecret secret) async {
    final fp = secret.fingerprint; // may throw MnemonicException → caught above
    if (await _store.exists(_key(fp))) {
      return Err(DuplicateSeedFailure(fp));
    }
    try {
      await _store.store(_key(fp), secret.toStorageBytes());
    } on SecretAlreadyExistsException {
      // A concurrent import won the race between exists() and store().
      return Err(DuplicateSeedFailure(fp));
    }
    await _index.upsert(secret.toInfo(createdAt: DateTime.now()));
    return Ok(fp);
  }

  @override
  Future<Result<Fingerprint, SecretsFailure>> importMnemonic({
    required List<String> words,
    String? passphrase,
  }) =>
      _guard(() => _persist(
            MnemonicSeedSecret(words: words, passphrase: passphrase),
          ));

  @override
  Future<Result<Fingerprint, SecretsFailure>> generateMnemonic({
    MnemonicLength length = MnemonicLength.words12,
  }) =>
      _guard(() {
        final m = bip39.Mnemonic.generate(
          bip39.Language.english,
          length: length == MnemonicLength.words12
              ? bip39.MnemonicLength.words12
              : bip39.MnemonicLength.words24,
        );
        return _persist(MnemonicSeedSecret(words: m.words));
      });

  @override
  Future<Result<Fingerprint, SecretsFailure>> importBytes(Uint8List bytes) =>
      _guard(() => _persist(BytesSeedSecret(bytes)));

  @override
  Future<Result<void, SecretsFailure>> delete(Fingerprint fp) => _guard(() async {
        await _store.trash(_key(fp));
        await _index.remove(fp);
        return const Ok<void, SecretsFailure>(null);
      });

  @override
  Future<Result<bool, SecretsFailure>> exists(Fingerprint fp) =>
      _guard(() async => Ok(await _store.exists(_key(fp))));

  @override
  Future<Result<List<SeedInfo>, SecretsFailure>> listSeeds() =>
      _guard(() async => Ok(await _index.all()));

  @override
  Future<Result<SeedInfo?, SecretsFailure>> getInfo(Fingerprint fp) =>
      _guard(() async => Ok(await _index.get(fp)));

  @override
  Future<Result<Fingerprint, SecretsFailure>> fingerprintOf({
    required List<String> words,
    String? passphrase,
  }) =>
      _guard(() async =>
          Ok(MnemonicSeedSecret(words: words, passphrase: passphrase)
              .fingerprint));

  /// Runs [body], converting any foreign exception into a sanitized
  /// [SecretsFailure]. `dart:core` `Error`s propagate (programmer bugs).
  Future<Result<T, SecretsFailure>> _guard<T>(
    Future<Result<T, SecretsFailure>> Function() body,
  ) async {
    try {
      return await body();
    } on KeychainLockedException catch (e) {
      return Err(KeychainLockedFailure(sanitizeLog(e.toString())));
    } on bip39.MnemonicException catch (e) {
      return Err(InvalidMnemonicFailure(sanitizeLog(e.toString())));
    } on Exception catch (e) {
      return Err(SecretsUnexpectedFailure(sanitizeLog(e.toString())));
    }
  }
}
