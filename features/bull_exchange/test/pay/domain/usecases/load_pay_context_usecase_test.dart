import 'package:bull_exchange/src/pay/domain/pay_flow.dart';
import 'package:bull_exchange/src/pay/domain/usecases/load_pay_context_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../pay_fixtures.dart';

void main() {
  test('opens with the session account summary and the open journal '
      'entries', () async {
    final journal = InMemoryUnknownWriteJournal();
    await journal.record(
      const UnknownWriteDraft(
        kind: UnknownWriteKind.payin,
        environment: ExchangeEnvironment.mainnet,
        orderId: 'p-1',
        request: {'orderId': 'p-1'},
      ),
    );
    final asked = <ExchangeEnvironment?>[];
    final read = await LoadPayContextUsecase(
      exchangeForTesting(
        getUserSummary: (environment) async {
          asked.add(environment);
          return Ok(paySummary);
        },
        unknownWrites: journal,
        readSessionPoint: () async =>
            const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
      ),
    ).execute(paySession);
    final context = (read as ReadGot<PayContext>).value;
    expect(context.summary, paySummary);
    expect(context.openEntries.map((e) => e.orderId), ['p-1']);
    expect(asked, [ExchangeEnvironment.mainnet]);
  });

  test('an unreadable journal starts with no entries', () async {
    final read = await LoadPayContextUsecase(
      exchangeForTesting(
        getUserSummary: (_) async => Ok(paySummary),
        unknownWrites: InMemoryUnknownWriteJournal(),
        readSessionPoint: () async => const Err(ExchangeNetworkFailure()),
      ),
    ).execute(paySession);
    expect((read as ReadGot<PayContext>).value.openEntries, isEmpty);
  });

  test('a failed summary read is the answer', () async {
    final read = await LoadPayContextUsecase(
      exchangeForTesting(
        getUserSummary: (_) async =>
            const Err(ExchangeSessionRejectedFailure()),
      ),
    ).execute(paySession);
    expect(read, isA<ReadSessionRejected<PayContext>>());
  });
}
