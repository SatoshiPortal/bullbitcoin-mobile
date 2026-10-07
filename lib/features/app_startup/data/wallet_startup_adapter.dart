import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_wallet_port.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:meta/meta.dart';

final class WalletStartupAdapter implements AppStartupWalletPort {
  final RecoverBullFeature _recoverBull;

  const WalletStartupAdapter(this._recoverBull);

  @override
  @useResult
  Future<Result<bool, AppStartupFailure>>
  hasMainnetBitcoinEncryptedBackup() async {
    final status = await _recoverBull.status(RecoverBullNetwork.mainnet);
    if (!status.isKnown) {
      return const Err(
        AppStartupWalletCheckFailure('RecoverBull status is unavailable'),
      );
    }
    return Ok(status.hasEncryptedBackup);
  }
}
