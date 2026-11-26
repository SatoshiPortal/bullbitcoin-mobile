import 'package:bull_exchange/src/sell/domain/sell_flow.dart';
import 'package:bull_exchange/src/sell/domain/usecases/load_sell_context_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../sell_fixtures.dart';

void main() {
  test('opens with the session account summary and the open journal '
      'entries', () async {
    final journal = InMemoryUnknownWriteJournal();
    await journal.record(
      const UnknownWriteDraft(
        kind: UnknownWriteKind.payin,
        environment: ExchangeEnvironment.mainnet,
        orderId: 's-1',
        request: {'orderId': 's-1'},
      ),
    );
    final asked = <ExchangeEnvironment?>[];
    final read = await LoadSellContextUsecase(
      exchangeForTesting(
        getUserSummary: (environment) async {
          asked.add(environment);
          return Ok(sellSummary);
        },
        unknownWrites: journal,
        readSessionPoint: () async =>
            const Ok((environment: ExchangeEnvironment.mainnet, epoch: 1)),
      ),
    ).execute(sellSession);
    final context = (read as ReadGot<SellContext>).value;
    expect(context.summary, sellSummary);
    expect(context.openEntries.map((e) => e.orderId), ['s-1']);
    expect(asked, [ExchangeEnvironment.mainnet]);
  });

  test('an unreadable journal starts with no entries', () async {
    final read = await LoadSellContextUsecase(
      exchangeForTesting(
        getUserSummary: (_) async => Ok(sellSummary),
        unknownWrites: InMemoryUnknownWriteJournal(),
        readSessionPoint: () async => const Err(ExchangeNetworkFailure()),
      ),
    ).execute(sellSession);
    expect((read as ReadGot<SellContext>).value.openEntries, isEmpty);
  });

  test('a failed summary read is the answer', () async {
    final read = await LoadSellContextUsecase(
      exchangeForTesting(
        getUserSummary: (_) async =>
            const Err(ExchangeSessionRejectedFailure()),
      ),
    ).execute(sellSession);
    expect(read, isA<ReadSessionRejected<SellContext>>());
  });
}
