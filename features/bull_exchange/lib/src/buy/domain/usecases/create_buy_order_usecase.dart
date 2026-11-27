import 'package:bull_exchange/src/buy/domain/buy_flow.dart';
import 'package:bull_exchange/src/buy/domain/buy_payjoin.dart';
import 'package:bull_exchange/src/buy/domain/buy_payjoin_uris.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

/// Places the buy order through the account's write gate. With a payjoin
/// wallet it first opens a receiver on it and sends its URI with the order:
/// a done create keeps the URI on the order, an unknown one keeps it for
/// the order a later find matches, and a create that took no effect drops
/// the receiver. An unknown outcome is journaled so the next start
/// reconciles it.
class CreateBuyOrderUsecase {
  final Exchange _exchange;
  final PayjoinReceiver _payjoinReceiver;
  final BuyPayjoinUris _uris;

  const CreateBuyOrderUsecase(
    this._exchange,
    this._payjoinReceiver,
    this._uris,
  );

  Future<OrderCreateAnswered<BuyRequest, BuyOrder>> execute(
    ExchangeSession session,
    OrderSendCreate<BuyRequest> effect,
  ) async {
    BuyPayjoinReceiver? receiver;
    final answer = await runOrderCreate<BuyRequest, BuyOrder>(
      gate: _exchange.writeGate,
      session: session,
      effect: effect,
      create: (request) async {
        final walletId = request.payjoinWalletId;
        if (walletId != null) {
          receiver = await startBuyPayjoin(
            _payjoinReceiver,
            walletId: walletId,
            network: BitcoinNetwork.fromName(session.environment.name),
            address: request.destination.address,
            amountSat: request.amount.sats,
          );
        }
        return _exchange
            .orders(session.environment)
            .placeBuyOrder(
              toAddress: request.destination.address,
              orderAmount: request.orderAmount,
              currency: request.currency,
              network: request.network,
              isOwner: true,
              payjoinBip21: receiver?.bip21,
            );
      },
      journalUnknown: (request) =>
          _exchange.journalUnknownOrderCreate(session, request.journal),
    );
    final attached = receiver;
    if (attached == null) return answer;
    switch (answer.answer) {
      case GateAdmitted(result: Ok(:final value)):
        _uris.attachToOrder(value.orderId, attached.bip21);
        return OrderCreateAnswered(
          answer.attempt,
          GateAdmitted(Ok(_uris.withBip21(value))),
        );
      // The order may exist and pay through this receiver.
      case GateAdmitted(
        result: Err(failure: ExchangeWriteOutcomeUnknownFailure()),
      ):
        _uris.attachToRequest(effect.request, attached.bip21);
        return answer;
      case GateAdmitted(
            result: Err(failure: ExchangeWriteRefusedFailure()) ||
                Err(failure: ExchangeWriteNotSentFailure()) ||
                Err(failure: ExchangeSessionRejectedFailure()),
          ) ||
          GateRefused():
        await dropBuyPayjoin(_payjoinReceiver, attached.id);
        return answer;
    }
  }
}
