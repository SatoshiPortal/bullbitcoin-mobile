import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart'
    show SecretStoreKeys;
import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/data/models/mnemonic.dart';
import 'package:secrets/src/domain/log_sanitizer.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';

/// The SINGLE security-critical chokepoint for reading a secret and converting
/// foreign exceptions into a sanitized [SecretsFailure]. Defined once so the
/// rules every adapter depends on — `KeychainLocked` ≠ `SeedNotFound`, sanitize
/// `logMessage`, invalid mnemonic → `InvalidMnemonicFailure` — cannot drift
/// across copy-pasted `try/catch` blocks.
///
/// `useAndForget` is reached only from here + the sealed UI reader, keeping the
/// secret's lifetime minimal and the allow-list tiny.
class SecretGuard {
  const SecretGuard(this._store);
  final SecretStorePort _store;

  /// Reads the stored [Mnemonic] for [seed] and runs [use]. [onError] builds the
  /// adapter-specific failure for an unexpected foreign exception (already
  /// sanitized).
  Future<Result<T, SecretsFailure>> read<T>(
    Fingerprint seed,
    Future<Result<T, SecretsFailure>> Function(Mnemonic mnemonic) use, {
    required SecretsFailure Function(String sanitizedLog) onError,
  }) =>
      run(
        () => _store.useAndForget(
          SecretStoreKeys.seedKey(seed.hex),
          (bytes) => use(Mnemonic.fromStorageBytes(bytes)),
        ),
        seed: seed,
        onError: onError,
      );

  /// Runs [body], converting any foreign exception ONCE. `dart:core` `Error`s
  /// (programmer bugs) propagate and crash, by design.
  Future<Result<T, SecretsFailure>> run<T>(
    Future<Result<T, SecretsFailure>> Function() body, {
    Fingerprint? seed,
    required SecretsFailure Function(String sanitizedLog) onError,
  }) async {
    try {
      return await body();
    } on KeychainLockedException catch (e) {
      return Err(KeychainLockedFailure(sanitizeLog(e.toString())));
    } on SecretNotFoundException catch (e) {
      return Err(seed != null
          ? SeedNotFoundFailure(seed)
          : onError(sanitizeLog(e.toString())));
    } on bip39.MnemonicException catch (e) {
      return Err(InvalidMnemonicFailure(sanitizeLog(e.toString())));
    } on Exception catch (e) {
      return Err(onError(sanitizeLog(e.toString())));
    }
  }
}
