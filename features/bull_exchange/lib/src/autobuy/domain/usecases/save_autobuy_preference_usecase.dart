import 'package:bull_exchange/src/autobuy/domain/autobuy_state.dart';
import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

/// Saves the AutoBuy preference of the session's account through its write
/// gate. A save that returns normally is not proof the account changed: it
/// answers an unknown outcome, so the step re-reads the account (verify
/// after write).
class SaveAutoBuyPreferenceUsecase {
  final Exchange _exchange;

  const SaveAutoBuyPreferenceUsecase(this._exchange);

  Future<ConfirmAnswered<AutoBuyTarget, bool>> execute(
    ExchangeSession session,
    ConfirmSend<AutoBuyTarget> effect,
  ) => runServerConfirm(
    gate: _exchange.writeGate,
    session: session,
    policy: autoBuyWritePolicy,
    effect: effect,
    confirm: (target) async => switch (writeOfResult(
      await _exchange.updatePreferences(
        session,
        ExchangePreferencesPatch(autoBuyEnabled: target.enabled),
      ),
    )) {
      Ok() => const Err(
        ExchangeWriteOutcomeUnknownFailure(
          'saved; verified by re-reading the account',
        ),
      ),
      Err(:final failure) => Err(failure),
    },
  );
}
