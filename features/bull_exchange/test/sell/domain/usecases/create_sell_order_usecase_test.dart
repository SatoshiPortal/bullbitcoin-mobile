import 'package:bull_exchange/src/sell/domain/sell_flow.dart';
import 'package:bull_exchange/src/sell/domain/usecases/create_sell_order_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../sell_fixtures.dart';

final class _Orders extends Fake implements OrdersRepository {
  final ExchangeWrite<Order> answer;
  final placed = <String>[];

  _Orders(this.answer);

  @override
  Future<ExchangeWrite<SellOrder>> placeSellOrder({
    required OrderAmount orderAmount,
    required FiatCurrency currency,
    required BtcNetwork network,
    bool usePayjoin = false,
  }) async {
    placed.add('sell ${currency.code} ${network.name} payjoin=$usePayjoin');
    return switch (answer) {
      WriteDone(value: final SellOrder order) => WriteDone(order),
      WriteOutcomeUnknown(:final reason) => WriteOutcomeUnknown(reason),
      _ => throw StateError('no such sell answer in this test'),
    };
  }

  @override
  Future<ExchangeWrite<FiatPaymentOrder>> placePayOrder({
    required OrderAmount orderAmount,
    required String recipientId,
    required BtcNetwork network,
    String? paymentDescription,
    SepaPaymentProcessor? paymentProcessor,
    bool usePayjoin = false,
    String? securityQuestion,
    String? securityAnswer,
  }) async {
    placed.add('pay $recipientId ${network.name} payjoin=$usePayjoin');
    return switch (answer) {
      WriteOutcomeUnknown(:final reason) => WriteOutcomeUnknown(reason),
      _ => throw StateError('no such pay answer in this test'),
    };
  }
}

final class _Policy extends Fake implements PayjoinPolicyAccess {
  final Result<PayjoinPolicy, PayjoinFailure> answer;
  var loads = 0;

  _Policy(this.answer);

  @override
  Future<Result<PayjoinPolicy, PayjoinFailure>> load() async {
    loads++;
    return answer;
  }
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

OrderSendCreate<SellRequest> _sendFrom(
  SellFlowState state,
  SellFlowEvent event,
) {
  final next = transitionSellFlow(state, event);
  final effect = next.effects.whereType<SellOrderEffect>().single;
  return effect.effect as OrderSendCreate<SellRequest>;
}

/// The create the flow sends for 10 CAD to the balance, from the app
/// wallet on chain.
OrderSendCreate<SellRequest> _toBalance() => _sendFrom(
  sellPayoutState,
  const SellPayoutPicked(SellPayoutChoice.balance),
);

/// The create the flow sends for 10 CAD to the bank recipient.
OrderSendCreate<SellRequest> _toRecipient() =>
    _sendFrom(sellRecipientState, SellRecipientPicked(sellBankRecipient));

void main() {
  test('a sell to the balance asks for payjoin when the wallet allows '
      'it', () async {
    final orders = _Orders(WriteDone<Order>(sellOrder()));
    final environments = <ExchangeEnvironment>[];
    final answer = await CreateSellOrderUsecase(
      exchangeForTesting(
        orders: (environment) {
          environments.add(environment);
          return orders;
        },
      ),
      _policy(sellEnabled: true),
    ).execute(sellSession, _toBalance());
    expect(answer.attempt, 1);
    expect(
      answer.answer,
      isA<GateAdmitted<ExchangeWrite<Order>>>().having(
        (a) => a.result,
        'result',
        isA<WriteDone<Order>>(),
      ),
    );
    expect(orders.placed, ['sell CAD bitcoin payjoin=true']);
    expect(environments, [ExchangeEnvironment.mainnet]);
  });

  test('no payjoin when the wallet setting is off or unreadable', () async {
    for (final policy in [
      _policy(sellEnabled: false),
      _Policy(const Err(PayjoinUnavailableFailure())),
    ]) {
      final orders = _Orders(WriteDone<Order>(sellOrder()));
      await CreateSellOrderUsecase(
        exchangeForTesting(orders: (_) => orders),
        policy,
      ).execute(sellSession, _toBalance());
      expect(orders.placed, ['sell CAD bitcoin payjoin=false']);
    }
  });

  test('a sell to a recipient is a pay order; an unknown outcome is '
      'journaled as an order create of the session', () async {
    final journal = InMemoryUnknownWriteJournal();
    final orders = _Orders(const WriteOutcomeUnknown('lost'));
    await CreateSellOrderUsecase(
      exchangeForTesting(
        orders: (_) => orders,
        unknownWrites: journal,
        readSessionPoint: () async =>
            const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
      ),
      _policy(sellEnabled: true),
    ).execute(sellSession, _toRecipient());
    expect(orders.placed, ['pay r-bank bitcoin payjoin=true']);
    final (entry, settlement) = journal.entries.single;
    expect(entry.kind, UnknownWriteKind.orderCreate);
    expect(entry.environment, ExchangeEnvironment.mainnet);
    expect(entry.sessionEpoch, sellSession.epoch);
    expect(settlement, isNull);
  });
}
