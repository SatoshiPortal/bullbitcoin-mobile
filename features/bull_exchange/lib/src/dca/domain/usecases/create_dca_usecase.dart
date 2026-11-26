import 'package:bull_exchange/src/dca/domain/dca_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';

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
      WriteDone() => WriteDone(plan),
      WriteRefused(:final reason) => WriteRefused(reason),
      WriteNotSent(:final reason) => WriteNotSent(reason),
      WriteSessionRejected() => const WriteSessionRejected(),
      WriteOutcomeUnknown(:final reason) => WriteOutcomeUnknown(reason),
    },
  );
}
