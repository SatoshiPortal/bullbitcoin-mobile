import 'package:bull_exchange/src/buy/domain/buy_accelerate_flow.dart';
import 'package:bull_exchange/src/buy/domain/usecases/load_accelerate_quote_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../../payin/payin_fixtures.dart';
import '../../buy_fixtures.dart';
import '../../buy_test_ports.dart';

const _options = FeeOptions(
  fastest: RelativeFee(2500),
  economic: RelativeFee(1250),
  slow: RelativeFee(500),
  minRelay: RelativeFee(25),
);

final class _Fees extends Fake implements Fees {
  final Result<FeeOptions, FeesFailure> answer;
  final asked = <Network>[];

  _Fees(this.answer);

  @override
  Future<Result<FeeOptions, FeesFailure>> estimate(
    Network network, {
    FeeSource? source,
  }) async {
    asked.add(network);
    return answer;
  }
}

final class _LimitOrders extends Fake implements LimitOrdersRepository {
  final Result<LimitOrderRate, ExchangeFailure> answer;
  final asked = <String>[];

  _LimitOrders(this.answer);

  @override
  Future<Result<LimitOrderRate, ExchangeFailure>> getRate(
    String currencyCode,
  ) async {
    asked.add(currencyCode);
    return answer;
  }
}

final _rate = _LimitOrders(
  Ok(LimitOrderRate(currencyCode: 'CAD', indexPrice: 50000, userPrice: 51000)),
);

Future<ExchangeRead<AccelerateQuote>> _load({
  required BuyTestOrders orders,
  _Fees? fees,
  _LimitOrders? rate,
}) {
  final exchange = exchangeForTesting(
    orders: (_) => orders,
    limitOrders: rate ?? _rate,
    unknownWrites: InMemoryUnknownWriteJournal(),
    readSessionPoint: () async =>
        const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
  );
  return LoadAccelerateQuoteUsecase(
    exchange,
    fees ?? _Fees(const Ok(_options)),
    GetOrderUsecase(exchange),
  ).execute(buySession, 'b-1');
}

void main() {
  test('quotes the fastest fee for a typical express payout in the order '
      'currency', () async {
    final orders = BuyTestOrders()
      ..read = Ok(buyOrder(status: OrderStatus.inProgress));
    final fees = _Fees(const Ok(_options));
    final rate = _LimitOrders(
      Ok(LimitOrderRate(currencyCode: 'CAD', indexPrice: 50000, userPrice: 1)),
    );
    final read = await _load(orders: orders, fees: fees, rate: rate);
    final quote = (read as ReadGot<AccelerateQuote>).value;
    expect(quote.order.orderId, 'b-1');
    expect(quote.fee.satPerVbyte, _options.fastest.value.toDouble());
    expect(quote.fee.sats, _options.toAbsolute(140).fastest.value.toInt());
    expect(quote.fee.fiatPerBitcoin, 50000);
    expect(quote.openEntries, isEmpty);
    expect(orders.log, ['read b-1']);
    expect(fees.asked, [BitcoinNetwork.mainnet]);
    expect(rate.asked, ['CAD']);
  });

  test('an order of another class is malformed, with nothing else '
      'read', () async {
    final fees = _Fees(const Ok(_options));
    final read = await _load(
      orders: BuyTestOrders()..read = Ok(payinOrder()),
      fees: fees,
    );
    expect(read, isA<ReadMalformed<AccelerateQuote>>());
    expect(fees.asked, isEmpty);
  });

  test('unreadable fees are unreachable; a failed rate is the '
      'answer', () async {
    final orders = BuyTestOrders()..read = Ok(buyOrder());
    expect(
      await _load(
        orders: orders,
        fees: _Fees(const Err(FeeEstimateUnavailableFailure())),
      ),
      isA<ReadUnreachable<AccelerateQuote>>().having(
        (r) => r.reason,
        'reason',
        'network fees',
      ),
    );
    expect(
      await _load(
        orders: orders,
        rate: _LimitOrders(const Err(ExchangeSessionRejectedFailure())),
      ),
      isA<ReadSessionRejected<AccelerateQuote>>(),
    );
  });
}
