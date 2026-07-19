import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_failure.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_transaction.dart';
import 'package:bb_mobile/features/get_paid/domain/list_get_paid_transactions_usecase.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_transaction_history_cubit.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_transaction_history_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockListTransactions extends Mock
    implements ListGetPaidTransactionsUsecase {}

GetPaidTransaction _transaction(
  String id, {
  int amountSat = 1000,
  GetPaidTransactionSource source = GetPaidTransactionSource.lightningAddress,
}) {
  return GetPaidTransaction(
    transactionId: id,
    source: source,
    invoiceId: source == GetPaidTransactionSource.lightningAddress
        ? null
        : '50000000-0000-4000-8000-000000000005',
    amountSat: amountSat,
    receivedAt: DateTime.utc(2026),
    rail: GetPaidTransactionRail.lightning,
    settlementState: GetPaidSettlementState.settled,
    late: false,
    comment: null,
  );
}

void main() {
  const firstId = '10000000-0000-4000-8000-000000000001';
  const secondId = '20000000-0000-4000-8000-000000000002';
  const thirdId = '30000000-0000-4000-8000-000000000003';
  late _MockListTransactions list;
  late GetPaidTransactionHistoryCubit cubit;

  setUp(() {
    list = _MockListTransactions();
    cubit = GetPaidTransactionHistoryCubit(listTransactions: list);
  });

  tearDown(() => cubit.close());

  test('loads the first page and exposes its opaque cursor', () async {
    when(() => list.execute(cursor: '', limit: 20)).thenAnswer(
      (_) async => Ok(
        GetPaidTransactionPage(
          transactions: [_transaction(firstId)],
          nextCursor: 'next',
        ),
      ),
    );

    final states = <GetPaidTransactionHistoryState>[];
    final subscription = cubit.stream.listen(states.add);
    addTearDown(subscription.cancel);
    await cubit.load();

    expect(states.first.status, GetPaidTransactionHistoryStatus.loading);
    expect(cubit.state.status, GetPaidTransactionHistoryStatus.loaded);
    expect(cubit.state.transactions.single.transactionId, firstId);
    expect(cubit.state.nextCursor, 'next');
  });

  test('first-page failure becomes a retryable screen state', () async {
    when(
      () => list.execute(cursor: '', limit: 20),
    ).thenAnswer((_) async => const Err(GetPaidFailure.unavailable()));

    await cubit.refresh();

    expect(cubit.state.status, GetPaidTransactionHistoryStatus.failure);
    expect(cubit.state.failure, isA<GetPaidUnavailableFailure>());
    expect(cubit.state.transactions, isEmpty);
  });

  test('load more deduplicates by source and transaction id', () async {
    when(() => list.execute(cursor: '', limit: 20)).thenAnswer(
      (_) async => Ok(
        GetPaidTransactionPage(
          transactions: [_transaction(firstId), _transaction(secondId)],
          nextCursor: 'page-2',
        ),
      ),
    );
    when(() => list.execute(cursor: 'page-2', limit: 20)).thenAnswer(
      (_) async => Ok(
        GetPaidTransactionPage(
          transactions: [
            _transaction(secondId, amountSat: 2000),
            _transaction(thirdId),
          ],
          nextCursor: null,
        ),
      ),
    );

    await cubit.load();
    await cubit.loadMore();

    expect(cubit.state.transactions.length, 3);
    expect(cubit.state.transactions[1].amountSat, 2000);
    expect(cubit.state.nextCursor, isNull);
    expect(cubit.state.hasMore, isFalse);
  });

  test(
    'pagination failure preserves the loaded page and exposes retry',
    () async {
      when(() => list.execute(cursor: '', limit: 20)).thenAnswer(
        (_) async => Ok(
          GetPaidTransactionPage(
            transactions: [_transaction(firstId)],
            nextCursor: 'page-2',
          ),
        ),
      );
      when(
        () => list.execute(cursor: 'page-2', limit: 20),
      ).thenAnswer((_) async => const Err(GetPaidFailure.unavailable()));

      await cubit.load();
      await cubit.loadMore();

      expect(cubit.state.status, GetPaidTransactionHistoryStatus.loaded);
      expect(cubit.state.transactions.single.transactionId, firstId);
      expect(cubit.state.nextCursor, 'page-2');
      expect(cubit.state.isLoadingMore, isFalse);
      expect(cubit.state.loadMoreFailed, isTrue);
    },
  );

  test('a stale refresh cannot overwrite a newer refresh', () async {
    final first = Completer<Result<GetPaidTransactionPage, GetPaidFailure>>();
    final second = Completer<Result<GetPaidTransactionPage, GetPaidFailure>>();
    var call = 0;
    when(
      () => list.execute(cursor: '', limit: 20),
    ).thenAnswer((_) => call++ == 0 ? first.future : second.future);

    final firstRefresh = cubit.refresh();
    final secondRefresh = cubit.refresh();
    second.complete(
      Ok(
        GetPaidTransactionPage(
          transactions: [_transaction(secondId)],
          nextCursor: null,
        ),
      ),
    );
    await secondRefresh;
    first.complete(
      Ok(
        GetPaidTransactionPage(
          transactions: [_transaction(firstId)],
          nextCursor: null,
        ),
      ),
    );
    await firstRefresh;

    expect(cubit.state.transactions.single.transactionId, secondId);
  });
}
