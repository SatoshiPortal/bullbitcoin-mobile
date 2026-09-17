import 'package:bip39_mnemonic/bip39_mnemonic.dart' show MnemonicException;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/crypto.dart'
    show InvalidVault, UnsupportedLiquidNetwork;
import 'package:secrets/src/data/exceptions.dart';
import 'package:secrets/src/domain/domain.dart';

/// The package's one `try/catch`: an exception becomes a [SecretFailure] here and nowhere else.
///
/// Called by the two repositories only, so `public/` never catches. Two rules live in the table: a sealed keystore is never an absence, and no foreign message travels — anything this package did not raise is reported by type ([describeSafely]).
///
/// [orElse] names the failure an unrecognised `Exception` becomes; it is the repository method's category — a read, a write, a delete, a derivation — not a message.
Future<Result<T, SecretFailure>> boundary<T>(
  Future<T> Function() body, {
  required SecretFailure Function(String) orElse,
}) async {
  try {
    return Ok(await body());
  } on SecretStoreLockedException catch (e) {
    // Must not collapse into not-found: callers read that as "the seed is gone" and may offer destructive recovery.
    log.warning('Keystore locked: ${e.message}');
    return Err(SecretStoreLockedFailure(e.message));
  } on ModuleKeyCorruptException catch (e, st) {
    // Names the storage key, never a value. Nothing was overwritten.
    log.severe(
      message: 'Corrupt module key: ${e.message}',
      error: describeSafely(e),
      trace: st,
    );
    return Err(DatabaseKeyCorruptFailure(e.message));
  } on SecretIdentityMismatch catch (e) {
    return Err(SecretIdentityMismatchFailure(e.message));
  } on SecretIdentityConflict catch (e) {
    return Err(SecretStoreFailure(e.message));
  } on UnsupportedLiquidNetwork catch (e) {
    return Err(UnsupportedNetworkFailure(e.message));
  } on InvalidVault catch (e) {
    return Err(InvalidVaultFailure(e.message));
  } on MnemonicException catch (e) {
    // bip39 quotes the offending word, so only the type travels — enough to tell unknown word, bad checksum and wrong count apart.
    return Err(InvalidMnemonicFailure(describeSafely(e)));
  } on Exception catch (e, st) {
    // An unrecognised `Exception` becomes the caller's category. Only the type travels.
    final safe = describeSafely(e);
    log.severe(message: 'secrets: operation failed', error: safe, trace: st);
    return Err(orElse(safe));
  } on Error catch (e, st) {
    // An `Error` is a programmer bug and keeps propagating to the crash report (AGENTS.md, rule 11) — but not with a message this package did not write: a library's Error can quote its input. The type and the stack trace leave; the text does not.
    final safe = describeSafely(e);
    log.severe(message: 'secrets: $safe', error: safe, trace: st);
    Error.throwWithStackTrace(StateError('secrets: $safe'), st);
  }
}
