import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../exchange_settings_failure.dart';

class GetExchangeStatisticsUsecase {
  final Exchange _exchange;

  const GetExchangeStatisticsUsecase({required this._exchange});

  @useResult
  Future<Result<OrderStatistics, ExchangeSettingsFailure>> execute() async =>
      (await _exchange.getOrderStats()).mapErr(
        (_) => const ExchangeSettingsStatisticsUnavailableFailure(),
      );
}
