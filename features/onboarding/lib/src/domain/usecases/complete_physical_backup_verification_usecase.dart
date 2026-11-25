import 'package:bull_logger/bull_logger.dart';
import 'package:bull_recoverbull/storage.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import '../onboarding_failure.dart';

/// Records that the restored default pair's physical backup was verified.
class CompletePhysicalBackupVerificationUsecase {
  final RecoverBullWalletBackups Function(Network) _records;

  const CompletePhysicalBackupVerificationUsecase({required this._records});

  @useResult
  Future<Result<void, OnboardingFailure>> execute(
    List<WalletRegistration> wallets,
  ) async {
    final bitcoin = wallets
        .where((wallet) => wallet.network is BitcoinNetwork)
        .toList();
    if (bitcoin.length != 1) return _failed('Bitcoin default unavailable');
    final wallet = bitcoin.single;
    final fingerprint = wallet.secretFingerprint;
    if (fingerprint == null ||
        wallet.signer != WalletSigner.local ||
        wallets.any(
          (other) =>
              other.signer != WalletSigner.local ||
              other.secretFingerprint != fingerprint ||
              other.network.env != wallet.network.env,
        )) {
      return _failed('default secret unavailable');
    }
    return switch (await _records(wallet.network).recordPhysicalVerification(
      walletId: wallet.id,
      fingerprint: fingerprint,
    )) {
      Ok() => const Ok(null),
      Err(:final failure) => _failed(
        'backup verification failed: ${failure.runtimeType}',
      ),
    };
  }

  /// Keeps the reporting route of the former thrown exception, with a fixed
  /// reason and no wallet data.
  Err<void, OnboardingFailure> _failed(String reason) {
    log.severe(
      message: 'Onboarding: backup verification failed',
      error: reason,
      trace: StackTrace.current,
    );
    return const Err(OnboardingBackupVerificationFailure());
  }
}
