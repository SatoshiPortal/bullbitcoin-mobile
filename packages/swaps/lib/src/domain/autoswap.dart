import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../log.dart';
import 'entities/auto_swap.dart';
import 'entities/swap_failure.dart';
import 'entities/swap_route.dart';

typedef _ReadSettings = Future<Result<AutoSwap, AutoswapFailure>> Function();
typedef _RunProvider = Future<Result<String, AutoswapFailure>> Function(
  AutoSwap settings,
);

/// Decides whether to start an automatic swap and which provider may run it.
///
/// The host supplies wallet and payment operations and serializes execution
/// (the foreground watcher permits one run at a time).
/// [AutoswapBoltzUnavailableFailure] and [AutoswapAmountOutOfBoundsFailure]
/// from the Boltz callback must mean no swap was created. An exception does
/// not establish that and never permits fallback.
abstract interface class Autoswap {
  static Autoswap open({
    required Future<Result<AutoSwap, AutoswapFailure>> Function() readSettings,
    required Future<SwapRoute> Function() resolveRoute,
    required Future<Result<String, AutoswapFailure>> Function(AutoSwap)
    runBoltz,
    required Future<Result<String, AutoswapFailure>> Function(AutoSwap)
    runExchange,
  }) => _Autoswap(readSettings, resolveRoute, runBoltz, runExchange);

  @useResult
  Future<Result<String, AutoswapFailure>> execute();
}

final class _Autoswap implements Autoswap {
  final _ReadSettings _readSettings;
  final Future<SwapRoute> Function() _resolveRoute;
  final _RunProvider _runBoltz;
  final _RunProvider _runExchange;

  const _Autoswap(
    this._readSettings,
    this._resolveRoute,
    this._runBoltz,
    this._runExchange,
  );

  @override
  @useResult
  Future<Result<String, AutoswapFailure>> execute() async {
    try {
      return await _execute();
    } on Exception catch (error) {
      // A thrown provider exception does not establish that no write happened.
      return Err(AutoswapExecutionFailure(error.runtimeType.toString()));
    }
  }

  Future<Result<String, AutoswapFailure>> _execute() async {
    final AutoSwap settings;
    switch (await _readSettings()) {
      case Ok(:final value):
        settings = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (!settings.enabled || settings.showWarning) {
      return const Err(AutoswapDisabledFailure());
    }
    if (settings.violation case final violation?) {
      return Err(AutoswapInvalidSettingsFailure(violation));
    }
    final route = await _resolveRoute();
    if (!route.startsWithBoltz) return _runExchange(settings);
    final result = await _runBoltz(settings);
    if (result
        case Err(
          failure: AutoswapBoltzUnavailableFailure() ||
              AutoswapAmountOutOfBoundsFailure(),
        )
        when route == SwapRoute.boltzWithExchangeFallback) {
      swapsLog.fine(
        '[Autoswap] Boltz cannot take the transfer, using the exchange',
      );
      return _runExchange(settings);
    }
    return result;
  }
}
