import 'package:bull_logger/bull_logger.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Turns the account's DCA preference on after a create. The recurring buy
/// exists either way, so a failure is only logged.
class ActivateDcaUsecase {
  final Exchange _exchange;

  const ActivateDcaUsecase(this._exchange);

  Future<void> execute() async {
    final enabled = await _exchange.updateCurrentPreferences(
      const ExchangePreferencesPatch(dcaEnabled: true),
    );
    if (enabled case Err(:final failure)) {
      log.warning(
        'DCA created but enabling the preference failed',
        error: failure.runtimeType,
      );
    }
  }
}
