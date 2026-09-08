import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class LoadWalletsForNetworkUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  LoadWalletsForNetworkUsecase({
    required this._walletRepository,
    required this._settingsRepository,
  });

  /// The bitcoin wallets for the active environment.
  ///
  /// This is the feature's boundary for the shared settings and wallet
  /// repositories, which still throw. An empty list is reported as
  /// [TestWalletBackupNoWalletsFailure] rather than an empty `Ok`, because every caller
  /// needs a wallet and would otherwise have to re-check it.
  @useResult
  Future<Result<List<Wallet>, TestWalletBackupFailure>> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final wallets = await _walletRepository.getWallets(
        onlyDefaults: false,
        onlyBitcoin: true,
        environment: settings.environment,
      );
      if (wallets.isEmpty) return const Err(TestWalletBackupNoWalletsFailure());
      return Ok(wallets);
    } on Object catch (e, st) {
      log.severe(
        message: 'Failed to load wallets for the backup test',
        error: e,
        trace: st,
      );
      return Err(TestWalletBackupWalletsUnavailableFailure(e.toString()));
    }
  }
}
