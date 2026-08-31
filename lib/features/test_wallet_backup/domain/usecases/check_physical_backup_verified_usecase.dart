import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CheckPhysicalBackupVerifiedUsecase {
  final WalletRepository _walletRepository;

  const CheckPhysicalBackupVerifiedUsecase(this._walletRepository);

  Future<bool> execute(String fingerprint) async {
    final normalized = fingerprint.toLowerCase();
    if (!RegExp(r'^[0-9a-f]{8}$').hasMatch(normalized)) return false;

    final wallets = await _walletRepository.getWallets(onlyBitcoin: true);
    return wallets.any(
      (wallet) =>
          wallet.isPhysicalBackupTested &&
          wallet.localMasterFingerprints.any(
            (value) => value.toLowerCase() == normalized,
          ),
    );
  }
}
