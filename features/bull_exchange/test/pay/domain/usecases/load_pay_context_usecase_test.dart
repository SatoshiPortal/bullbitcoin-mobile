import 'package:bull_exchange/src/pay/domain/pay_state.dart';
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
        access: fixedAccessForTesting(ExchangeAccessSignedIn(paySession)),
        unknownWrites: journal,
      ),
    ).execute(paySession);
    final context = (read as Ok<PayContext, ExchangeReadFailure>).value;
    expect(context.summary, paySummary);
    expect(context.openEntries.map((e) => e.orderId), ['p-1']);
    expect(asked, [ExchangeEnvironment.mainnet]);
  });

  test('a session that is no longer current starts with no entries', () async {
    final read = await LoadPayContextUsecase(
      exchangeForTesting(
        getUserSummary: (_) async => Ok(paySummary),
        unknownWrites: InMemoryUnknownWriteJournal(),
      ),
    ).execute(paySession);
    expect(
      (read as Ok<PayContext, ExchangeReadFailure>).value.openEntries,
      isEmpty,
    );
  });

  test('a failed summary read is the answer', () async {
    final read = await LoadPayContextUsecase(
      exchangeForTesting(
        getUserSummary: (_) async => const Err(
          ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
        ),
      ),
    ).execute(paySession);
    expect(
      read,
      isA<Err<PayContext, ExchangeReadFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<ExchangeSessionRejectedFailure>(),
      ),
    );
  });
}
