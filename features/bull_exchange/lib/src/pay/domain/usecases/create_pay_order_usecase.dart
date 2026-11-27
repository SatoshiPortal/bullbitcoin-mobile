import 'package:bull_exchange/src/pay/domain/pay_state.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

/// Places the pay order to the chosen recipient through the account's
/// write gate, with the description when the user typed one. It asks for a
/// payjoin URI only for an on-chain payin from an app wallet, and only when
/// the wallet's payjoin setting allows it. An unknown outcome is journaled
/// so the next start reconciles it.
class CreatePayOrderUsecase {
  final Exchange _exchange;
  final PayjoinPolicyAccess _payjoinPolicy;

  const CreatePayOrderUsecase(this._exchange, this._payjoinPolicy);

  Future<OrderCreateAnswered<PayRequest, Order>> execute(
    ExchangeSession session,
    OrderSendCreate<PayRequest> effect,
  ) => runOrderCreate(
    gate: _exchange.writeGate,
    session: session,
    effect: effect,
    create: (request) async => _exchange
        .orders(session.environment)
        .placePayOrder(
          orderAmount: FiatAmount(request.amount.fiat),
          recipientId: request.payout.recipientId,
          network: request.source.rail,
          paymentDescription: request.amount.description.isEmpty
              ? null
              : request.amount.description,
          paymentProcessor: request.payout.paymentProcessor,
          usePayjoin: await _payjoinAsked(request.source),
          securityQuestion: request.payout.interacAnswer?.question,
          securityAnswer: request.payout.interacAnswer?.answer,
        ),
    journalUnknown: (request) =>
        _exchange.journalUnknownOrderCreate(session, request.journal),
  );

  Future<bool> _payjoinAsked(PayinSource source) async {
    if (source case PayinFromAppWallet(rail: BtcNetwork.bitcoin)) {
      return switch (await _payjoinPolicy.load()) {
        Ok(:final value) => value.sellEnabled,
        Err() => false,
      };
    }
    return false;
  }
}
