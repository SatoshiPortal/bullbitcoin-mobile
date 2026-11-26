import 'package:bull_exchange/src/dca/domain/dca_flow.dart';
import 'package:bull_exchange/src/dca/domain/usecases/create_dca_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../dca_fixtures.dart';

final class _Orders extends Fake implements ExchangeOrders {
  final ExchangeWrite<Dca> answer;
  final created = <String>[];

  _Orders(this.answer);

  @override
  Future<ExchangeWrite<Dca>> createDca({
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
    required BtcNetwork network,
    required String address,
  }) async {
    created.add(
      '$amount ${currency.code} ${frequency.name} ${network.name} $address',
    );
    return answer;
  }
}

ConfirmSend<DcaPlan> _send() =>
    applyDca(dcaReviewState, const [
          DcaConfirmPressed(),
        ]).effects.whereType<DcaConfirmEffect>().single.effect
        as ConfirmSend<DcaPlan>;

void main() {
  test('a done create answers the reviewed plan', () async {
    final environments = <ExchangeEnvironment>[];
    final orders = _Orders(WriteDone(_dca()));
    final send = _send();
    final answer = await CreateDcaUsecase(
      exchangeForTesting(
        orders: (environment) {
          environments.add(environment);
          return orders;
        },
      ),
    ).execute(buySession, send);
    expect(answer.attempt, send.attempt);
    final result =
        (answer.answer as GateAdmitted<ExchangeWrite<DcaPlan>>).result;
    expect((result as WriteDone<DcaPlan>).value, dcaPlan);
    expect(orders.created, ['10.0 CAD weekly bitcoin bc1qdefault']);
    expect(environments, [ExchangeEnvironment.mainnet]);
  });

  test('an unknown outcome is kept, never read as created', () async {
    final answer = await CreateDcaUsecase(
      exchangeForTesting(
        orders: (_) => _Orders(const WriteOutcomeUnknown('lost')),
        unknownWrites: InMemoryUnknownWriteJournal(),
        readSessionPoint: () async =>
            const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
      ),
    ).execute(buySession, _send());
    expect(
      (answer.answer as GateAdmitted<ExchangeWrite<DcaPlan>>).result,
      isA<WriteOutcomeUnknown<DcaPlan>>(),
    );
  });
}

Dca _dca() => Dca(
  amount: 10,
  currency: FiatCurrency.cad,
  frequency: DcaBuyFrequency.weekly,
  network: BtcNetwork.bitcoin,
  address: 'bc1qdefault',
  nextPurchaseDate: DateTime.utc(2026, 12),
);
