import 'dart:async';

import 'package:bull_exchange/src/withdraw/domain/usecases/create_withdraw_order_usecase.dart';
import 'package:bull_exchange/src/withdraw/domain/withdraw_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../withdraw_fixtures.dart';

final class _Orders extends Fake implements ExchangeOrders {
  final ExchangeWrite<WithdrawOrder> answer;
  final placed = <Map<String, Object?>>[];
  final confirmed = <(String, Object?)>[];

  _Orders(this.answer);

  @override
  Future<ExchangeWrite<WithdrawOrder>> placeWithdrawalOrder({
    required double fiatAmount,
    required String recipientId,
    SepaPaymentProcessor? paymentProcessor,
    String? securityQuestion,
    String? securityAnswer,
  }) async {
    placed.add({
      'fiatAmount': fiatAmount,
      'recipientId': recipientId,
      'securityQuestion': securityQuestion,
      'securityAnswer': securityAnswer,
    });
    return answer;
  }

  @override
  Future<ExchangeWrite<WithdrawOrder>> confirmWithdrawOrder(
    String orderId, {
    ({
      String recipientId,
      String email,
      String? securityQuestion,
      String? securityAnswer,
    })?
    interacUpdate,
  }) async {
    confirmed.add((orderId, interacUpdate));
    return answer;
  }
}

/// The create the flow sends for 10 CAD to the bank recipient.
OrderSendCreate<WithdrawRequest> _send() {
  final next = transitionWithdrawFlow(
    withdrawRecipientState,
    WithdrawRecipientPicked(withdrawBankRecipient),
  );
  final effect = next.effects.single as WithdrawOrderEffect;
  return effect.effect as OrderSendCreate<WithdrawRequest>;
}

void main() {
  test('places the withdrawal for the amount and recipient', () async {
    final orders = _Orders(WriteDone(withdrawOrder()));
    final send = _send();
    final answer = await CreateWithdrawOrderUsecase(
      exchangeForTesting(orders: (_) => orders),
    ).execute(withdrawSession, send);
    expect(answer.attempt, send.attempt);
    expect(
      answer.answer,
      isA<GateAdmitted<ExchangeWrite<WithdrawOrder>>>().having(
        (a) => a.result,
        'result',
        isA<WriteDone<WithdrawOrder>>(),
      ),
    );
    expect(orders.placed, [
      {
        'fiatAmount': 10.0,
        'recipientId': 'r-bank',
        'securityQuestion': null,
        'securityAnswer': null,
      },
    ]);
  });

  test('an unknown outcome is journaled as an order create of the '
      'session', () async {
    final journal = InMemoryUnknownWriteJournal();
    await CreateWithdrawOrderUsecase(
      exchangeForTesting(
        orders: (_) => _Orders(const WriteOutcomeUnknown('lost')),
        unknownWrites: journal,
        readSessionPoint: () async =>
            const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
      ),
    ).execute(withdrawSession, _send());
    final (entry, settlement) = journal.entries.single;
    expect(entry.kind, UnknownWriteKind.orderCreate);
    expect(entry.environment, ExchangeEnvironment.mainnet);
    expect(entry.sessionEpoch, withdrawSession.epoch);
    expect(entry.request['recipientId'], 'r-bank');
    expect(settlement, isNull);
  });

  test('a held write gate refuses without placing', () async {
    final orders = _Orders(WriteDone(withdrawOrder()));
    final gate = ExchangeWriteGate();
    final held = Completer<void>();
    final holding = gate.run(
      withdrawSession,
      FinancialWriteKind.orderCreate,
      () => held.future,
    );
    final answer = await CreateWithdrawOrderUsecase(
      exchangeForTesting(orders: (_) => orders, writeGate: gate),
    ).execute(withdrawSession, _send());
    expect(answer.answer, isA<GateRefused<ExchangeWrite<WithdrawOrder>>>());
    expect(orders.placed, isEmpty);
    held.complete();
    await holding;
  });
}
