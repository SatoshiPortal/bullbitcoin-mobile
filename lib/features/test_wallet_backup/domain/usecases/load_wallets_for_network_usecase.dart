import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

import 'package:bb_mobile/core/wallet/domain/wallet_failure_bridge.dart';
import 'package:bb_mobile/core/utils/result.dart';

class LoadWalletsForNetworkUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  LoadWalletsForNetworkUsecase({
    required this._walletRepository,
    required this._settingsRepository,
  });

  Future<List<Wallet>> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final wallets = switch (await _walletRepository.getWallets(
        onlyDefaults: false,
        onlyBitcoin: true,
        environment: settings.environment,
      )) {
        Ok(:final value) => value,
        // TODO(#1895): test_wallet_backup has no failure family yet. Map
        // WalletFailure into it instead of throwing once it does.
        Err(:final failure) => throw WalletFailureException(failure),
      };
      return wallets;
    } catch (e) {
      log.severe(error: e, trace: StackTrace.current);
      rethrow;
    }
  }
}
