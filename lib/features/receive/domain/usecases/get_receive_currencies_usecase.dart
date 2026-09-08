import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:meta/meta.dart';

/// Receive-owned boundary for the shared currencies use-case, which still
/// throws.
class GetReceiveCurrenciesUsecase {
  final GetAvailableCurrenciesUsecase _getAvailableCurrenciesUsecase;

  const GetReceiveCurrenciesUsecase(this._getAvailableCurrenciesUsecase);

  @useResult
  Future<Result<List<String>, ReceiveFailure>> execute() async {
    try {
      return Ok(await _getAvailableCurrenciesUsecase.execute());
    } on Object catch (e, st) {
      // Logged HERE, at the boundary that owns the raw reason. The failure's
      // logMessage stays secondary (equality, debug): if a caller chooses not
      // to log, the diagnostic must still exist.
      log.severe(
        message: 'Failed to load currencies for receive',
        error: e,
        trace: st,
      );
      return Err(ReceiveUnexpectedFailure(e.toString()));
    }
  }
}
