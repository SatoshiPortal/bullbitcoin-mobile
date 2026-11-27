import 'package:bull_exchange/src/dca/domain/dca_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

/// Creates the recurring buy of the reviewed plan through the account's
/// write gate; a done create answers the plan itself.
class CreateDcaUsecase {
  final Exchange _exchange;

  const CreateDcaUsecase(this._exchange);

  Future<ConfirmAnswered<DcaPlan, DcaPlan>> execute(
    ExchangeSession session,
    ConfirmSend<DcaPlan> effect,
  ) => runServerConfirm(
    gate: _exchange.writeGate,
    session: session,
    policy: dcaConfirmPolicy,
    effect: effect,
    confirm: (plan) async => switch (await _exchange
        .orders(session.environment)
        .createDca(
          amount: plan.fiat,
          currency: plan.currency,
          frequency: plan.frequency,
          network: plan.payout.network,
          address: plan.payout.address,
        )) {
      Ok() => Ok(plan),
      Err(failure: ExchangeWriteRefusedFailure(:final reason)) => Err(
        ExchangeWriteRefusedFailure(reason),
      ),
      Err(failure: ExchangeWriteNotSentFailure(:final reason)) => Err(
        ExchangeWriteNotSentFailure(reason),
      ),
      Err(failure: ExchangeSessionRejectedFailure()) => const Err(
        ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
      ),
      Err(failure: ExchangeWriteOutcomeUnknownFailure(:final reason)) => Err(
        ExchangeWriteOutcomeUnknownFailure(reason),
      ),
    },
  );
}
