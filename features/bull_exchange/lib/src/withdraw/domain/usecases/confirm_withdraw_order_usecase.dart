import 'package:bull_exchange/src/withdraw/domain/withdraw_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';

/// Confirms the withdrawal order through the account's write gate. An
/// Interac recipient's address goes with it, and its security answer too
/// when the user asked to save it as the recipient's default.
class ConfirmWithdrawOrderUsecase {
  final Exchange _exchange;

  const ConfirmWithdrawOrderUsecase(this._exchange);

  Future<ConfirmAnswered<WithdrawConfirmTarget, WithdrawOrder>> execute(
    ExchangeSession session,
    ConfirmSend<WithdrawConfirmTarget> effect,
  ) => runServerConfirm(
    gate: _exchange.writeGate,
    session: session,
    policy: withdrawConfirmPolicy,
    effect: effect,
    confirm: (target) => _exchange
        .orders(session.environment)
        .confirmWithdrawOrder(
          target.order.orderId,
          interacUpdate: _interacUpdate(target.recipient),
        ),
  );
}

({
  String recipientId,
  String email,
  String? securityQuestion,
  String? securityAnswer,
})?
_interacUpdate(ReadyRecipient recipient) {
  final evidence = recipient.interac;
  final details = recipient.chosen.recipient.details;
  if (evidence == null || details is! InteracEmailCadDetails) return null;
  final save = evidence.saveAsDefault;
  return (
    recipientId: recipient.chosen.recipient.recipientId,
    email: details.email,
    securityQuestion: save ? evidence.answer.question : null,
    securityAnswer: save ? evidence.answer.answer : null,
  );
}
