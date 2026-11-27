import 'package:bull_logger/bull_logger.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Turns the DCA preference of [session]'s account on after a create. The
/// recurring buy exists either way, so a failure (a session that is no
/// longer current included) is only logged.
class ActivateDcaUsecase {
  final Exchange _exchange;

  const ActivateDcaUsecase(this._exchange);

  Future<void> execute(ExchangeSession session) async {
    final enabled = await _exchange.updatePreferences(
      session,
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
