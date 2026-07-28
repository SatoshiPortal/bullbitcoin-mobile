import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:meta/meta.dart';

class LoadWalletsForNetworkUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  LoadWalletsForNetworkUsecase({
    required this._walletRepository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<List<Wallet>, TestWalletBackupFailure>> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final wallets = await _walletRepository.getWallets(
        onlyDefaults: false,
        onlyBitcoin: true,
        environment: settings.environment,
      );
      if (wallets.isEmpty) {
        const message = 'No Bitcoin wallets available for backup verification';
        log.warning(message);
        return const Err(TestWalletBackupLoadWalletsFailure(message));
      }
      return Ok(wallets);
    } on WalletError catch (error, trace) {
      return _failure(error, trace);
    } on Exception catch (error, trace) {
      return _failure(error, trace);
    }
  }

  Err<List<Wallet>, TestWalletBackupFailure> _failure(
    Object error,
    StackTrace trace,
  ) {
    log.severe(
      message: 'loadWalletsForNetwork failed',
      error: error,
      trace: trace,
    );
    return Err(TestWalletBackupLoadWalletsFailure(error.toString()));
  }
}
