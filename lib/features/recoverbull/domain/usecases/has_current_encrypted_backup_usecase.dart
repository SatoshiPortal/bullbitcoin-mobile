import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';

class HasCurrentEncryptedBackupUsecase {
  final GetWalletsUsecase _getWalletsUsecase;
  final GetSettingsUsecase _getSettingsUsecase;

  HasCurrentEncryptedBackupUsecase(
    this._getWalletsUsecase,
    this._getSettingsUsecase,
  );

  Future<bool> execute() async {
    final defaultWallets = await _getWalletsUsecase.execute(onlyDefaults: true);
    final settings = await _getSettingsUsecase.execute();
    final network = Network.fromEnvironment(
      isTestnet: settings.environment.isTestnet,
      isLiquid: false,
    );
    final wallet = defaultWallets
        .where((wallet) => wallet.network == network)
        .firstOrNull;
    return wallet?.latestEncryptedBackup != null;
  }
}
