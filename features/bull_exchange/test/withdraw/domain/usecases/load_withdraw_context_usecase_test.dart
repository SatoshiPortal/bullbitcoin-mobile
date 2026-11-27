import 'package:bull_exchange/src/withdraw/domain/usecases/load_withdraw_context_usecase.dart';
import 'package:bull_exchange/src/withdraw/domain/withdraw_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../withdraw_fixtures.dart';

void main() {
  test('opens with the session account summary and the open journal '
      'entries', () async {
    final journal = InMemoryUnknownWriteJournal();
    await journal.record(
      const UnknownWriteDraft(
        kind: UnknownWriteKind.withdrawConfirm,
        environment: ExchangeEnvironment.mainnet,
        orderId: 'w-1',
        request: {'orderId': 'w-1'},
      ),
    );
    final asked = <ExchangeEnvironment?>[];
    final read = await LoadWithdrawContextUsecase(
      exchangeForTesting(
        getUserSummary: (environment) async {
          asked.add(environment);
          return Ok(withdrawSummary);
        },
        access: fixedAccessForTesting(ExchangeAccessSignedIn(withdrawSession)),
        unknownWrites: journal,
      ),
    ).execute(withdrawSession);
    final context = (read as ReadGot<WithdrawContext>).value;
    expect(context.summary, withdrawSummary);
    expect(context.openEntries.map((e) => e.orderId), ['w-1']);
    expect(asked, [ExchangeEnvironment.mainnet]);
  });

  test('a session that is no longer current starts with no entries', () async {
    final read = await LoadWithdrawContextUsecase(
      exchangeForTesting(
        getUserSummary: (_) async => Ok(withdrawSummary),
        unknownWrites: InMemoryUnknownWriteJournal(),
      ),
    ).execute(withdrawSession);
    expect((read as ReadGot<WithdrawContext>).value.openEntries, isEmpty);
  });

  test('a failed summary read is the answer', () async {
    final read = await LoadWithdrawContextUsecase(
      exchangeForTesting(
        getUserSummary: (_) async => const Err(
          ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
        ),
      ),
    ).execute(withdrawSession);
    expect(read, isA<ReadSessionRejected<WithdrawContext>>());
  });
}
