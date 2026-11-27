import 'package:bull_exchange/src/buy/domain/buy_accelerate_flow.dart';
import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:fees/fees.dart';
import 'package:primitives/primitives.dart';

/// The size of a typical express payout, for its fee estimate.
const _expressPayoutVsize = 140;

/// Reads what the accelerate flow offers for one buy order: the order (any
/// other class is malformed), the fastest fee on the session's bitcoin
/// network as a rate and as the cost of a typical express payout, the
/// order currency's rate to show that cost in fiat, and the open journal
/// entries.
class LoadAccelerateQuoteUsecase {
  final Exchange _exchange;
  final Fees _fees;
  final GetOrderUsecase _getOrder;

  const LoadAccelerateQuoteUsecase(this._exchange, this._fees, this._getOrder);

  Future<ExchangeRead<AccelerateQuote>> execute(
    ExchangeSession session,
    String orderId,
  ) async {
    final BuyOrder order;
    switch (await _getOrder.execute(session, orderId)) {
      case ReadGot(value: final BuyOrder value):
        order = value;
      case ReadGot():
        return const ReadMalformed('not a buy order');
      case ReadMissing():
        return const ReadMissing();
      case ReadUnreachable(:final reason, :final isNetwork):
        return ReadUnreachable(reason, isNetwork: isNetwork);
      case ReadSessionRejected(:final why):
        return ReadSessionRejected(why);
      case ReadMalformed(:final reason):
        return ReadMalformed(reason);
    }
    final FeeOptions estimate;
    switch (await _fees.estimate(
      BitcoinNetwork.fromName(session.environment.name),
    )) {
      case Ok(:final value):
        estimate = value;
      case Err():
        return const ReadUnreachable('network fees', isNetwork: false);
    }
    final double fiatPerBitcoin;
    switch (await _exchange.limitOrders.getRate(order.payinCurrency)) {
      case Ok(:final value):
        fiatPerBitcoin = value.indexPrice;
      case Err(:final failure):
        return readOfExchangeFailure<AccelerateQuote>(failure);
    }
    final entries = switch (await _exchange.openUnknownWrites(session)) {
      Ok(:final value) => value,
      Err() => const <UnknownWrite>[],
    };
    return ReadGot(
      AccelerateQuote(
        order,
        AccelerateFee(
          satPerVbyte: estimate.fastest.value.toDouble(),
          sats: estimate.toAbsolute(_expressPayoutVsize).fastest.value.toInt(),
          fiatPerBitcoin: fiatPerBitcoin,
        ),
        entries,
      ),
    );
  }
}
