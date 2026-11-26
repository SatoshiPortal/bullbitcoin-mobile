import 'package:preferences/preferences.dart';
import 'package:swaps/swaps.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:swap_feature/src/domain/usecases/load_swap_wallets_usecase.dart';
import 'package:swap_feature/src/domain/entities/swap_wallet.dart';
import 'package:meta/meta.dart';

/// Everything the settings form needs to populate itself.
typedef AutoswapSettingsData = ({
  AutoSwap settings,
  BitcoinUnit bitcoinUnit,
  List<SwapWallet> bitcoinWallets,
  String? recipientWalletId,
});

class LoadAutoswapSettingsUsecase {
  final AutoSwapSettings _autoSwapSettings;
  final Preferences _getSettingsUsecase;
  final LoadSwapWalletsUsecase _walletRepository;

  const LoadAutoswapSettingsUsecase({
    required this._autoSwapSettings,
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
      final AutoSwap autoSwapSettings;
      switch (await _autoSwapSettings.readAutoSwap()) {
        case Ok(:final value):
          autoSwapSettings = value;
        case Err(failure: SwapsUnsupportedNetworkFailure()):
          return const Err(AutoswapUnsupportedNetworkFailure());
        case Err(:final failure):
          return Err(AutoswapSettingsUnavailableFailure(failure.logMessage));
      }

      final List<SwapWallet> wallets;
      switch (await _walletRepository.execute(
        appSettings.environment.networkEnv,
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
