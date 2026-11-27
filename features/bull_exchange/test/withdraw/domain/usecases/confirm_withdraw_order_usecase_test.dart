import 'package:bull_exchange/src/withdraw/domain/usecases/confirm_withdraw_order_usecase.dart';
import 'package:bull_exchange/src/withdraw/domain/withdraw_state.dart';
import 'package:bull_exchange/src/withdraw/domain/withdraw_event.dart';
import 'package:bull_exchange/src/withdraw/domain/withdraw_effect.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../recipients/recipient_fixture.dart';
import '../../withdraw_fixtures.dart';

import 'package:primitives/primitives.dart';

final class _Orders extends Fake implements OrdersRepository {
  final Result<WithdrawOrder, ExchangeWriteFailure> answer;
  final placed = <Map<String, Object?>>[];
  final confirmed = <(String, Object?)>[];

  _Orders(this.answer);

  @override
  Future<Result<WithdrawOrder, ExchangeWriteFailure>> placeWithdrawalOrder({
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
  Future<Result<WithdrawOrder, ExchangeWriteFailure>> confirmWithdrawOrder(
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

final _interac = recipientFixture(
  'r-interac',
  RecipientType.interacEmailCad,
  isOwner: true,
  email: 'ada@example.com',
  securityQuestion: 'Pet name?',
  securityAnswer: 'Rex',
).recipient;

/// The confirm the flow sends after a create for [recipient] answered done;
/// for an Interac recipient, after the security answer (saved as default
/// when [save]).
ConfirmSend<WithdrawConfirmTarget> _confirmFor(
  Recipient recipient, {
  bool save = false,
}) {
  final events = <WithdrawFlowEvent>[
    WithdrawRecipientPicked(recipient),
    if (recipient.recipientId == 'r-interac') ...[
      WithdrawRequirementsChanged(
        RequirementInteracEvent(InteracSaveAsDefaultSet(save: save)),
      ),
      const WithdrawRequirementsChanged(
        RequirementInteracEvent(InteracContinuePressed()),
      ),
    ],
    WithdrawOrderChanged(OrderCreateAnswered(1, Ok(withdrawOrder()))),
  ];
  final review = applyWithdraw(withdrawRecipientState, events);
  final next = review.next(const WithdrawConfirmPressed());
  final effect = next.effects.single as WithdrawConfirmEffect;
  return effect.effect as ConfirmSend<WithdrawConfirmTarget>;
}

Future<_Orders> _confirm(ConfirmSend<WithdrawConfirmTarget> send) async {
  final orders = _Orders(Ok(withdrawOrder()));
  final answer = await ConfirmWithdrawOrderUsecase(
    exchangeForTesting(orders: (_) => orders),
  ).execute(withdrawSession, send);
  expect(answer.attempt, send.attempt);
  expect(
    answer.answer,
    isNot(
      isA<Err<WithdrawOrder, ExchangeGatedWriteFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeWriteBusyFailure>(),
      ),
    ),
  );
  return orders;
}

void main() {
  test('a bank recipient confirms the order with no Interac update', () async {
    final orders = await _confirm(_confirmFor(withdrawBankRecipient));
    expect(orders.confirmed, [('w-1', null)]);
  });

  test('an Interac recipient sends its email; the answer only when saved as '
      'default', () async {
    final kept = await _confirm(_confirmFor(_interac));
    expect(kept.confirmed.single.$2, (
      recipientId: 'r-interac',
      email: 'ada@example.com',
      securityQuestion: null,
      securityAnswer: null,
    ));
    final saved = await _confirm(_confirmFor(_interac, save: true));
    expect(saved.confirmed.single.$2, (
      recipientId: 'r-interac',
      email: 'ada@example.com',
      securityQuestion: 'Pet name?',
      securityAnswer: 'Rex',
    ));
  });
}
