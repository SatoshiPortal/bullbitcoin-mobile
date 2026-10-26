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
/// again, and only if they are the ones a wallet was built from.
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
    final expected = Fingerprint.tryParse(expectedFingerprint);
    if (expected == null) {
      return const Err(AppStartupRestoreFailure('unparseable fingerprint'));
    }

    // Accepted before anything is written: the missing wallet's words, or
    // another local wallet's, which puts that wallet's seed back too. Any
    // other words are refused without touching the keystore.
    final accepted = {expected, ...await _localFingerprints()};
    final Secret secret;
    switch (await _secrets.import(words: words, acceptOnly: accepted)) {
      case Ok(:final value):
        secret = value;
      case Err(failure: SecretAlreadyExistsFailure()):
        // Already stored, so not the missing one: its fingerprint is taken.
        return const Err(AppStartupRestoreMismatchFailure('already stored'));
      case Err(failure: InvalidMnemonicFailure()):
        return const Err(AppStartupRestoreMismatchFailure('invalid words'));
      case Err(failure: FingerprintMismatchFailure()):
        return const Err(AppStartupRestoreMismatchFailure('another wallet'));
      case Err(:final failure):
        log.warning('Restore default secret: ${failure.runtimeType}');
        return Err(AppStartupRestoreFailure('${failure.runtimeType}'));
    }

    if (secret.id == expected) {
      log.info('Restore default secret: ${secret.id} is back');
      return const Ok(null);
    }
    return const Err(AppStartupRestoreMismatchFailure('another wallet'));
  }

  /// Fingerprints of the wallets that sign with a stored seed. A failed read
  /// accepts none of them: only the missing wallet's words are then stored.
  Future<Set<Fingerprint>> _localFingerprints() async {
    switch (await _walletRepository.getWallets()) {
      case Ok(:final value):
        return {
          for (final w in value)
            if (w.signsLocally) ?Fingerprint.tryParse(w.masterFingerprint),
        };
      case Err(:final failure):
        log.warning('Restore default secret check: ${failure.runtimeType}');
        return const {};
    }
  }
}
