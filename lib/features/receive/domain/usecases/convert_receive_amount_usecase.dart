import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:meta/meta.dart';

/// Receive-owned boundary for the shared rate conversion, which still throws.
class ConvertReceiveAmountUsecase {
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;

  const ConvertReceiveAmountUsecase(this._convertSatsToCurrencyAmountUsecase);

  @useResult
  Future<Result<double, ReceiveFailure>> execute({
    BigInt? amountSat,
    String? currencyCode,
  }) async {
    try {
      return Ok(
        await _convertSatsToCurrencyAmountUsecase.execute(
          amountSat: amountSat,
          currencyCode: currencyCode,
        ),
      );
    } on Object catch (e, st) {
      // Logged HERE, at the boundary that owns the raw reason. The failure's
      // logMessage stays secondary (equality, debug): if a caller chooses not
      // to log, the diagnostic must still exist.
      log.severe(
        message: 'Failed to convert an amount for receive',
        error: e,
        trace: st,
      );
      return Err(ReceiveUnexpectedFailure(e.toString()));
    }
  }
}
