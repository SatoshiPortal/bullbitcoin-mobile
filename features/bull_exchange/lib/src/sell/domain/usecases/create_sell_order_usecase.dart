import 'package:bull_exchange/src/sell/domain/sell_state.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

/// Places the sell order through the account's write gate: a sell to the
/// balance, or a pay order to the chosen recipient. It asks for a payjoin
/// URI only for an on-chain payin from an app wallet, and only when the
/// wallet's payjoin setting allows it. An unknown outcome is journaled so
/// the next start reconciles it.
class CreateSellOrderUsecase {
  final Exchange _exchange;
  final PayjoinPolicyAccess _payjoinPolicy;

  const CreateSellOrderUsecase(this._exchange, this._payjoinPolicy);

  Future<OrderCreateAnswered<SellRequest, Order>> execute(
    ExchangeSession session,
    OrderSendCreate<SellRequest> effect,
  ) => runOrderCreate(
    gate: _exchange.writeGate,
    session: session,
    effect: effect,
    create: (request) async {
      final orders = _exchange.orders(session.environment);
      final usePayjoin = await _payjoinAsked(request.source);
      return switch (request.payout) {
        SellToBalance() => orders.placeSellOrder(
          orderAmount: request.orderAmount,
          currency: request.amount.market.currency,
          network: request.source.rail,
          usePayjoin: usePayjoin,
        ),
        SellToRecipient(:final recipient) => orders.placePayOrder(
          orderAmount: request.orderAmount,
          recipientId: recipient.orderParams.recipientId,
          network: request.source.rail,
          paymentProcessor: recipient.orderParams.paymentProcessor,
          usePayjoin: usePayjoin,
          securityQuestion: recipient.orderParams.interacAnswer?.question,
          securityAnswer: recipient.orderParams.interacAnswer?.answer,
        ),
      };
    },
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
