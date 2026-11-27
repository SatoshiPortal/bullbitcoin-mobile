import 'package:bull_exchange/src/pay/domain/pay_state.dart';
import 'package:bull_exchange/src/pay/domain/pay_event.dart';
import 'package:bull_exchange/src/pay/domain/pay_effect.dart';
import 'package:bull_exchange/src/pay/domain/usecases/create_pay_order_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../pay_fixtures.dart';

final class _Orders extends Fake implements OrdersRepository {
  final Result<FiatPaymentOrder, ExchangeWriteFailure> answer;
  final placed = <Map<String, Object?>>[];

  _Orders(this.answer);

  @override
  Future<Result<FiatPaymentOrder, ExchangeWriteFailure>> placePayOrder({
    required OrderAmount orderAmount,
    required String recipientId,
    required BtcNetwork network,
    String? paymentDescription,
    SepaPaymentProcessor? paymentProcessor,
    bool usePayjoin = false,
    String? securityQuestion,
    String? securityAnswer,
  }) async {
    placed.add({
      'orderAmount': '${orderAmount.runtimeType} ${orderAmount.amount}',
      'recipientId': recipientId,
      'network': network,
      'paymentDescription': paymentDescription,
      'usePayjoin': usePayjoin,
    });
    return answer;
  }
}

final class _Policy extends Fake implements PayjoinPolicyAccess {
  final Result<PayjoinPolicy, PayjoinFailure> answer;

  _Policy(this.answer);

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> load() async => answer;
}

_Policy _policy({required bool sellEnabled}) => _Policy(
  Ok(
    PayjoinPolicy(
      sendEnabled: true,
      receiveEnabled: false,
      buyEnabled: true,
      sellEnabled: sellEnabled,
      minimumAmount: PayjoinPolicy.minimumAllowedAmount,
      sessionLifetime: const Duration(hours: 1),
    ),
  ),
);

/// The create the flow sends for 10 CAD to the bank recipient from the app
/// wallet on chain, with [description] typed on the amount page.
OrderSendCreate<PayRequest> _send({String description = ''}) {
  final source = applyPay(payAmountState, [
    if (description.isNotEmpty)
      PayAmountChanged(AmountDescriptionTyped(description)),
    const PayAmountChanged(AmountTyped('10')),
    const PayAmountChanged(AmountContinuePressed()),
  ]);
  final next = source.next(const PaySourcePicked(payAppWallet));
  final effect = next.effects.whereType<PayOrderEffect>().single;
  return effect.effect as OrderSendCreate<PayRequest>;
}

void main() {
  test('places a pay order to the recipient in the session environment, '
      'asking for payjoin when the wallet allows it', () async {
    final orders = _Orders(Ok(payOrder()));
    final environments = <ExchangeEnvironment>[];
    final answer = await CreatePayOrderUsecase(
      exchangeForTesting(
        orders: (environment) {
          environments.add(environment);
          return orders;
        },
      ),
      _policy(sellEnabled: true),
    ).execute(paySession, _send());
    expect(
      answer.answer,
      isA<GateAdmitted<Result<Order, ExchangeWriteFailure>>>().having(
        (a) => a.result,
        'result',
        isA<Ok<Order, ExchangeWriteFailure>>(),
      ),
    );
    expect(orders.placed, [
      {
        'orderAmount': 'FiatAmount 10.0',
        'recipientId': 'r-bank',
        'network': BtcNetwork.bitcoin,
        'paymentDescription': null,
        'usePayjoin': true,
      },
    ]);
    expect(environments, [ExchangeEnvironment.mainnet]);
  });

  test('the description typed on the amount page goes with the '
      'order', () async {
    final orders = _Orders(Ok(payOrder()));
    await CreatePayOrderUsecase(
      exchangeForTesting(orders: (_) => orders),
      _policy(sellEnabled: false),
    ).execute(paySession, _send(description: 'rent'));
    expect(orders.placed.single['paymentDescription'], 'rent');
  });

  test('no payjoin when the wallet setting is off or unreadable', () async {
    for (final policy in [
      _policy(sellEnabled: false),
      _Policy(const Err(PayjoinUnavailableFailure())),
    ]) {
      final orders = _Orders(Ok(payOrder()));
      await CreatePayOrderUsecase(
        exchangeForTesting(orders: (_) => orders),
        policy,
      ).execute(paySession, _send());
      expect(orders.placed.single['usePayjoin'], isFalse);
    }
  });

  test('an unknown outcome is journaled as an order create of the '
      'session', () async {
    final journal = InMemoryUnknownWriteJournal();
    await CreatePayOrderUsecase(
      exchangeForTesting(
        orders: (_) =>
            _Orders(const Err(ExchangeWriteOutcomeUnknownFailure('lost'))),
        unknownWrites: journal,
        readSessionPoint: () async =>
            const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
      ),
      _policy(sellEnabled: false),
    ).execute(paySession, _send());
    final (entry, settlement) = journal.entries.single;
    expect(entry.kind, UnknownWriteKind.orderCreate);
    expect(entry.environment, ExchangeEnvironment.mainnet);
    expect(entry.sessionEpoch, paySession.epoch);
    expect(settlement, isNull);
  });
}
