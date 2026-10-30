import 'package:bb_mobile/core/price/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bull_pricer/bull_pricer.dart' show PricerUnexpectedFailure;
import 'package:meta/meta.dart';

/// Receive-owned boundary for the shared rate conversion.
class ConvertReceiveAmountUsecase {
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;

  const ConvertReceiveAmountUsecase(this._convertSatsToCurrencyAmountUsecase);

  @useResult
  Future<Result<double, ReceiveFailure>> execute({
    BigInt? amountSat,
    String? currencyCode,
  }) async {
    switch (await _convertSatsToCurrencyAmountUsecase.execute(
      amountSat: amountSat,
      currencyCode: currencyCode,
    )) {
      case Ok(:final value):
        return Ok(value);
      case Err(:final failure) when failure is PricerUnexpectedFailure:
        log.warning('Receive price conversion failed: ${failure.logMessage}');
        return Err(ReceiveUnexpectedFailure(failure.logMessage));
      case Err(:final failure):
        log.warning('Receive price unavailable: ${failure.runtimeType}');
        return const Ok(0);
    }
  }
}
