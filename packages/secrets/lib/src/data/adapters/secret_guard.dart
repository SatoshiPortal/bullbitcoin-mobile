import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart'
    show SecretStoreKeys;
import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/data/datasources/malformed_secret_exception.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/data/models/mnemonic.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';

/// The SINGLE security-critical chokepoint for reading a secret and converting
/// foreign exceptions into a [SecretsFailure]. Defined once so the rules every
/// adapter depends on — `KeychainLocked` ≠ `SeedNotFound`, invalid mnemonic →
/// `InvalidMnemonicFailure` — cannot drift across copy-pasted `try/catch`
/// blocks.
///
/// SECRET-SAFE LOGGING: a foreign exception's *message* can echo its secret
/// input (e.g. "bad mnemonic: zoo zoo zoo …", "invalid xprv: tprv8…"). Rather
/// than try to scrub that text (a losing game — see the removed log sanitizer),
/// we NEVER pass `e.toString()` into a failure. The only diagnostic recorded is
/// the exception's runtime *type* (a class name, never input) plus the
/// (public) fingerprint. Nothing sensitive can reach a log/Sentry sink.
///
/// `useAndForget` is reached only from here + the sealed UI reader, keeping the
/// secret's lifetime minimal and the allow-list tiny.
class SecretGuard {
  const SecretGuard(this._store);
  final SecretStorePort _store;

  /// Reads the stored [Mnemonic] for [seed] and runs [use]. [onError] builds the
  /// adapter-specific failure for an unexpected foreign exception; it receives
  /// only the exception's runtime type name (never its secret-bearing message).
  Future<Result<T, SecretsFailure>> read<T>(
    Fingerprint seed,
    Future<Result<T, SecretsFailure>> Function(Mnemonic mnemonic) use, {
    required SecretsFailure Function(String errorType) onError,
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
    required SecretsFailure Function(String errorType) onError,
  }) async {
    try {
      return await body();
    } on KeychainLockedException {
      return const Err(KeychainLockedFailure());
    } on SecretNotFoundException catch (e) {
      return Err(seed != null
          ? SecretNotFoundFailure(seed)
          : onError(e.runtimeType.toString()));
    } on bip39.MnemonicException catch (e) {
      // Record only the exception CLASS (e.g. MnemonicInvalidChecksumException);
      // `e.toString()` would echo the rejected mnemonic words.
      return Err(InvalidMnemonicFailure(e.runtimeType.toString()));
    } on MalformedSecretException catch (e) {
      // A malformed/unsupported stored blob means the stored secret isn't a
      // valid mnemonic — surface it as [InvalidMnemonicFailure] (a meaningful
      // typed failure), uniformly across every operation, NOT the per-adapter
      // catch-all. Only the exception CLASS is recorded, never its message.
      return Err(InvalidMnemonicFailure(e.runtimeType.toString()));
    } on Exception catch (e) {
      return Err(onError(e.runtimeType.toString()));
    }
  }
}
