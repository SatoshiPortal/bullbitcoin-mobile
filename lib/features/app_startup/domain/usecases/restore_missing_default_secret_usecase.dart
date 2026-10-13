import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Fingerprint;
import 'package:secrets/secrets.dart';

/// Puts a default wallet's missing seed back from the user's recovery phrase.
///
/// The wallets are still there, so nothing is created: the words are stored
/// again, and only if they are the ones the wallets were built from.
class RestoreMissingDefaultSecretUsecase {
  final Secrets _secrets;
  final WalletRepository _walletRepository;

  RestoreMissingDefaultSecretUsecase({
    required this._secrets,
    required this._walletRepository,
  });

  @useResult
  Future<Result<void, AppStartupFailure>> execute({
    required String expectedFingerprint,
    required List<String> words,
  }) async {
    final Secret secret;
    switch (await _secrets.import(words: words)) {
      case Ok(:final value):
        secret = value;
      case Err(failure: SecretAlreadyExistsFailure()):
        // Already stored, so not the missing one: its fingerprint is taken.
        return const Err(AppStartupRestoreMismatchFailure('already stored'));
      case Err(failure: InvalidMnemonicFailure()):
        return const Err(AppStartupRestoreMismatchFailure('invalid words'));
      case Err(:final failure):
        log.warning('Restore default secret: ${failure.runtimeType}');
        return Err(AppStartupRestoreFailure('${failure.runtimeType}'));
    }

    if (secret.id.hex == expectedFingerprint) {
      log.info('Restore default secret: ${secret.id} is back');
      return const Ok(null);
    }

    // Another wallet's words. The entry was just written by this call, so it
    // goes again — unless a wallet already uses it, which a cleanup must
    // never take from it.
    await _discardUnless(secret.id);
    return const Err(AppStartupRestoreMismatchFailure('another wallet'));
  }

  Future<void> _discardUnless(Fingerprint id) async {
    switch (await _walletRepository.getWallets()) {
      case Ok(:final value)
          when value.any(
            (w) =>
                w.signsLocally &&
                Fingerprint.tryParse(w.masterFingerprint) == id,
          ):
        return;
      case Ok():
        if (await _secrets.trash(id) case Err(:final failure)) {
          log.warning('Restore default secret cleanup: ${failure.runtimeType}');
        }
      case Err(:final failure):
        // Unknown counts as used: never delete on a failed read.
        log.warning('Restore default secret check: ${failure.runtimeType}');
    }
  }
}
