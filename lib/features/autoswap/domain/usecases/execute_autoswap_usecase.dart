import 'package:swaps/swaps.dart'
    show AutoSwap, AutoSwapSettings, SwapsUnsupportedNetworkFailure;
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_provider_port.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class ExecuteAutoswapUsecase {
  final AutoSwapSettings _settings;
  final SwapFacade _swapFacade;
  final AutoswapProviderPort _boltzProvider;
  final AutoswapProviderPort _exchangeProvider;

  const ExecuteAutoswapUsecase(
    this._settings,
    this._swapFacade, {
    required this._boltzProvider,
    required this._exchangeProvider,
  });

  @useResult
  Future<Result<String, AutoswapFailure>> execute() async {
    final AutoSwap settings;
    switch (await _settings.readAutoSwap()) {
      case Ok(:final value):
        settings = value;
      case Err(failure: SwapsUnsupportedNetworkFailure()):
        return const Err(AutoswapUnsupportedNetworkFailure());
      case Err(:final failure):
        return Err(AutoswapSettingsUnavailableFailure(failure.logMessage));
    }
    if (!settings.enabled || settings.showWarning) {
      return const Err(AutoswapDisabledFailure());
    }
    if (settings.violation case final violation?) {
      return Err(AutoswapInvalidSettingsFailure(violation));
    }
    final route = await _swapFacade.getRoute();
    if (!route.startsWithBoltz) return _exchangeProvider.execute(settings);
    final result = await _boltzProvider.execute(settings);
    if (result
        case Err(
          failure: AutoswapBoltzUnavailableFailure() ||
              AutoswapAmountOutOfBoundsFailure(),
        )
        when route == SwapRoute.boltzWithExchangeFallback) {
      log.fine('[Autoswap] Boltz cannot take the transfer, using the exchange');
      return _exchangeProvider.execute(settings);
    }
    return result;
  }
}
