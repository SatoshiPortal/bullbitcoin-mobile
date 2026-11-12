import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_provider_port.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class ExecuteAutoswapUsecase {
  final GetAutoSwapSettingsUsecase _getSettings;
  final SwapFacade _swapFacade;
  final AutoswapProviderPort _boltzProvider;
  final AutoswapProviderPort _exchangeProvider;

  const ExecuteAutoswapUsecase(
    this._getSettings,
    this._swapFacade, {
    required this._boltzProvider,
    required this._exchangeProvider,
  });

  @useResult
  Future<Result<String, AutoswapFailure>> execute() async {
    final settings = await _getSettings.execute();
    if (!settings.enabled || settings.showWarning) {
      return const Err(AutoswapDisabledFailure());
    }
    if (settings.violation case final violation?) {
      return Err(AutoswapInvalidSettingsFailure(violation));
    }
    final route = await _swapFacade.getRoute();
    if (!route.startsWithBoltz) return _exchangeProvider.execute(settings);
    final result = await _boltzProvider.execute(settings);
    if (result case Err(
      failure: AutoswapBoltzUnavailableFailure() ||
          AutoswapAmountOutOfBoundsFailure(),
    ) when route == SwapRoute.boltzWithExchangeFallback) {
      log.fine('[Autoswap] Boltz cannot take the transfer, using the exchange');
      return _exchangeProvider.execute(settings);
    }
    return result;
  }
}
