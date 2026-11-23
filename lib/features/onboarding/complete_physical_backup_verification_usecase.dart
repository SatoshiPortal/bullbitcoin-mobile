import 'package:bull_recoverbull/storage.dart';
import 'package:primitives/legacy_exceptions.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

class CompletePhysicalBackupVerificationUsecase {
  final RecoverBullWalletBackups _backups;
  final RecoverBullWalletBackups _regtestBackups;

  const CompletePhysicalBackupVerificationUsecase({
    required RecoverBullWalletBackups backups,
    required RecoverBullWalletBackups regtestBackups,
  }) : _backups = backups,
       _regtestBackups = regtestBackups;

  Future<void> execute(List<WalletRegistration> wallets) async {
    final bitcoin = wallets
        .where((wallet) => wallet.network is BitcoinNetwork)
        .toList();
    if (bitcoin.length != 1) {
      throw CompletePhysicalBackupVerificationException(
        'Bitcoin default unavailable',
      );
    }
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
      throw CompletePhysicalBackupVerificationException(
        'default secret unavailable',
      );
    }
    final records = wallet.network.env == NetworkEnv.regtest
        ? _regtestBackups
        : _backups;
    switch (await records.recordPhysicalVerification(
      walletId: wallet.id,
      fingerprint: fingerprint,
    )) {
      case Ok():
        return;
      case Err():
        throw CompletePhysicalBackupVerificationException(
          'backup verification failed',
        );
    }
  }
}

class CompletePhysicalBackupVerificationException extends BullException {
  CompletePhysicalBackupVerificationException(super.message);
}
