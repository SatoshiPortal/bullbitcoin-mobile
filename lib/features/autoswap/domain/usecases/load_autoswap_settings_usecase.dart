import 'package:bb_mobile/features/autoswap/domain/repositories/auto_swap_settings_repository.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
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
  final Preferences _getSettingsUsecase;
  final WalletRepository _walletRepository;

  const LoadAutoswapSettingsUsecase({
    required this._getAutoSwapSettingsUsecase,
    required this._getSettingsUsecase,
    required this._walletRepository,
  });

  @useResult
  Future<Result<AutoswapSettingsData, AutoswapFailure>> execute() async {
    try {
      final appSettings = (await _getSettingsUsecase.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
      final autoSwapSettings = await _getAutoSwapSettingsUsecase.execute();

      final List<Wallet> wallets;
      switch (await _walletRepository.getWallets(
        environment: appSettings.environment,
      )) {
        case Ok(:final value):
          wallets = value;
        case Err(:final failure):
          return Err(
            AutoswapSettingsUnavailableFailure(
              'wallets: ${failure.runtimeType}',
            ),
          );
      }
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
    } on AutoswapNetworkUnavailableException {
      return const Err(AutoswapUnsupportedNetworkFailure());
    } catch (e, st) {
      log.severe(
        message: 'Failed to load auto swap settings',
        error: e.runtimeType,
        trace: st,
      );
      return Err(AutoswapSettingsUnavailableFailure(e.runtimeType.toString()));
    }
  }
}
