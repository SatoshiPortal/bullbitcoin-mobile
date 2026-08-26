import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_wallet_port.dart';

final class WalletStartupAdapter implements AppStartupWalletPort {
  final RecoverBullFeature _recoverBull;

  const WalletStartupAdapter(this._recoverBull);

  @override
  Future<bool> hasMainnetBitcoinEncryptedBackup() async {
    return (await _recoverBull.status()).hasEncryptedBackup;
  }

  @override
  Future<bool> hasTestedRecoverBullBackup() async {
    return (await _recoverBull.status()).hasVerifiedEncryptedBackup;
  }
}
