import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_wallet_port.dart';
import 'package:meta/meta.dart';

final class WalletStartupAdapter implements AppStartupWalletPort {
  final WalletRepository _walletRepository;

  const WalletStartupAdapter(this._walletRepository);

  @override
  @useResult
  Future<Result<bool, AppStartupFailure>>
  hasMainnetBitcoinEncryptedBackup() async {
    return switch (await _walletRepository.getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
      environment: Environment.mainnet,
    )) {
      Ok(:final value) => Ok(
        value.isNotEmpty && value.first.latestEncryptedBackup != null,
      ),
      // The wallet repository already logged the raw reason.
      Err(:final failure) => Err(
        AppStartupWalletCheckFailure(
          'encrypted backup check failed: ${failure.runtimeType}',
        ),
      ),
    };
  }
}
