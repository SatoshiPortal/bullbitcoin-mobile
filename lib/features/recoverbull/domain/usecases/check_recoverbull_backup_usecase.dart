import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';

class CheckRecoverBullBackupUsecase {
  final GetWalletsUsecase _getWalletsUsecase;

  const CheckRecoverBullBackupUsecase(this._getWalletsUsecase);

  Future<bool> execute(String fingerprint) async {
    final normalized = fingerprint.toLowerCase();
    if (!RegExp(r'^[0-9a-f]{8}$').hasMatch(normalized)) return false;

    final wallets = await _getWalletsUsecase.execute(onlyBitcoin: true);
    return wallets.any(
      (wallet) =>
          wallet.isEncryptedVaultTested &&
          wallet.latestEncryptedBackup != null &&
          wallet.localMasterFingerprints.any(
            (value) => value.toLowerCase() == normalized,
          ),
    );
  }
}
