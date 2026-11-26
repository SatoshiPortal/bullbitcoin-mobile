import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Turns the recurring buy of the session's account off.
class StopDcaUsecase {
  final Exchange _exchange;

  const StopDcaUsecase(this._exchange);

  Future<Result<void, ExchangeFailure>> execute(ExchangeSession session) =>
      _exchange.updatePreferences(
        session,
        const ExchangePreferencesPatch(dcaEnabled: false),
      );
}
