import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class GetExchangeStatisticsUsecase {
  final Exchange _exchange;

  const GetExchangeStatisticsUsecase({required this._exchange});

  @useResult
  Future<Result<OrderStatsResponse, ExchangeSettingsFailure>> execute() async =>
      (await _exchange.getOrderStats()).mapErr(
        (_) => const ExchangeSettingsStatisticsUnavailableFailure(),
      );
}
