import 'package:bull_exchange/src/orders/domain/usecases/get_market_rate_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

final class _LimitOrders extends Fake implements LimitOrdersRepository {
  final Result<LimitOrderRate, ExchangeFailure> answer;
  final asked = <String>[];

  _LimitOrders(this.answer);

  @override
  Future<Result<LimitOrderRate, ExchangeFailure>> getRate(
    ExchangeSession session,
    String currencyCode,
  ) async {
    asked.add(currencyCode);
    return answer;
  }
}

const _session = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 's',
);

void main() {
  test('the rate is the index price in the market currency', () async {
    final orders = _LimitOrders(
      Ok(
        LimitOrderRate(
          currencyCode: 'EUR',
          indexPrice: 90000,
          userPrice: 91000,
        ),
      ),
    );
    final read = await GetMarketRateUsecase(
      exchangeForTesting(limitOrders: orders),
    ).execute(_session, ExchangeCatalog.eur);
    expect(read, isA<ReadGot<double>>().having((r) => r.value, 'value', 90000));
    expect(orders.asked, ['EUR']);
  });

  test('a failed read is never a rate', () async {
    final read = await GetMarketRateUsecase(
      exchangeForTesting(
        limitOrders: _LimitOrders(const Err(ExchangeNetworkFailure())),
      ),
    ).execute(_session, ExchangeCatalog.cad);
    expect(read, isA<ReadUnreachable<double>>());
  });
}
