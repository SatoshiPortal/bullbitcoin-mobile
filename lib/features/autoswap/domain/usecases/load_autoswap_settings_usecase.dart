import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:meta/meta.dart';

/// Everything the settings form needs to populate itself.
typedef AutoswapSettingsData = ({
  AutoSwap settings,
  BitcoinUnit bitcoinUnit,
  List<Wallet> bitcoinWallets,
  String? recipientWalletId,
});

class LoadAutoswapSettingsUsecase {
  final GetAutoSwapSettingsUsecase _getAutoSwapSettingsUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final WalletRepository _walletRepository;

  const LoadAutoswapSettingsUsecase({
    required this._getAutoSwapSettingsUsecase,
    required this._getSettingsUsecase,
    required this._walletRepository,
  });

  @useResult
  Future<Result<AutoswapSettingsData, AutoswapFailure>> execute() async {
    try {
      final appSettings = await _getSettingsUsecase.execute();
      final autoSwapSettings = await _getAutoSwapSettingsUsecase.execute();

      final wallets = await _walletRepository.getWallets(
        environment: appSettings.environment,
      );
      final bitcoinWallets = wallets.where((w) => !w.isLiquid).toList();
      final defaultBitcoinWallet = bitcoinWallets
          .where((w) => w.isDefault)
          .firstOrNull;

      return Ok((
        settings: autoSwapSettings,
        bitcoinUnit: appSettings.bitcoinUnit,
        bitcoinWallets: bitcoinWallets,
        recipientWalletId:
            autoSwapSettings.recipientWalletId ?? defaultBitcoinWallet?.id,
      ));
    } catch (e, st) {
      log.severe(
        message: 'Failed to load auto swap settings',
        error: e,
        trace: st,
      );
      return Err(AutoswapSettingsUnavailableFailure(e.runtimeType.toString()));
    }
  }
}
