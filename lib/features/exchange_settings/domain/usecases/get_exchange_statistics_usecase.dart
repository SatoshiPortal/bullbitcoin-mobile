import 'package:bb_mobile/core/exchange/domain/entity/order_stats.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_stats_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Wraps the shared exchange use-case, which still throws, so the cubit above
/// can switch on a `Result` instead of catching.
class GetExchangeStatisticsUsecase {
  final GetOrderStatsUsecase _getOrderStatsUsecase;

  const GetExchangeStatisticsUsecase({required this._getOrderStatsUsecase});

  @useResult
  Future<Result<OrderStatsResponse, ExchangeSettingsFailure>> execute() async {
    try {
      return Ok(await _getOrderStatsUsecase.execute());
    } catch (e, st) {
      // The raw reason is logged here, at the boundary, and goes no further:
      // the exchange API's text is operator-authored and not safe to surface.
      log.severe(message: 'getOrderStats failed', error: e, trace: st);
      return Err(
        ExchangeSettingsStatisticsUnavailableFailure(
          'getOrderStats failed: ${e.runtimeType}',
        ),
      );
    }
  }
}
