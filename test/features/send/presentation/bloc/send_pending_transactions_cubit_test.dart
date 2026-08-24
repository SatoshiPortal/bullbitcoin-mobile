import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/delete_pending_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_pending_bitcoin_transactions_usecase.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_pending_transactions_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchPending extends Mock
    implements WatchPendingBitcoinTransactionsUsecase {}

class _MockDeletePending extends Mock
    implements DeletePendingBitcoinTransactionUsecase {}

void main() {
  final transaction = PendingBitcoinTransaction(
    id: 'transaction',
    walletId: 'wallet',
    stage: PendingBitcoinTransactionStage.draft,
    recipient: '',
    amount: '',
    amountCurrencyCode: '',
    sendMax: false,
    feeSelection: FeeSelection.fastest,
    replaceByFee: true,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    revision: 3,
  );
  late _MockWatchPending watch;
  late _MockDeletePending delete;

  setUp(() {
    watch = _MockWatchPending();
    delete = _MockDeletePending();
  });

  test('keeps the loaded transactions when watching fails', () async {
    when(() => watch.execute('wallet')).thenAnswer(
      (_) => Stream.fromIterable([
        Ok(
          PendingBitcoinTransactionSnapshot(
            transactions: [transaction],
            invalidCount: 1,
          ),
        ),
        const Err<PendingBitcoinTransactionSnapshot, SendFailure>(
          SendPersistenceFailure(),
        ),
      ]),
    );
    final cubit = SendPendingTransactionsCubit(watch, delete);
    addTearDown(cubit.close);
    final emitted = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<SendPendingTransactionsState>()
            .having((state) => state.transactions, 'transactions', [
              transaction,
            ])
            .having((state) => state.invalidCount, 'invalidCount', 1)
            .having((state) => state.failure, 'failure', isNull),
        isA<SendPendingTransactionsState>()
            .having((state) => state.transactions, 'transactions', [
              transaction,
            ])
            .having((state) => state.invalidCount, 'invalidCount', 1)
            .having(
              (state) => state.failure,
              'failure',
              isA<SendPersistenceFailure>(),
            ),
      ]),
    );

    cubit.watch('wallet');

    await emitted;
  });

  test('deletes the displayed revision and exposes Send failures', () async {
    when(
      () => delete.execute(
        transaction.id,
        expectedRevision: transaction.revision,
      ),
    ).thenAnswer((_) async => const Err(SendPersistenceFailure()));
    final cubit = SendPendingTransactionsCubit(watch, delete);
    addTearDown(cubit.close);

    expect(await cubit.delete(transaction), isFalse);
    expect(cubit.state.failure, isA<SendPersistenceFailure>());
  });
}
