import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/repositories/pending_bitcoin_transaction_repository.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_pending_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_pending_bitcoin_transactions_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock
    implements PendingBitcoinTransactionRepository {}

class _MockValidatePendingBitcoinTransactionUsecase extends Mock
    implements ValidatePendingBitcoinTransactionUsecase {}

void main() {
  test(
    'keeps valid transactions when another stored transaction is invalid',
    () async {
      final repository = _MockRepository();
      final validate = _MockValidatePendingBitcoinTransactionUsecase();
      final valid = _draft('valid');
      final invalid = _draft('invalid');
      when(() => repository.watchWallet('wallet-id')).thenAnswer(
        (_) => Stream.value(
          Ok(
            PendingBitcoinTransactionSnapshot(
              transactions: [valid, invalid],
              invalidCount: 0,
            ),
          ),
        ),
      );
      when(() => validate.execute(valid)).thenAnswer((_) async => Ok(valid));
      when(() => validate.execute(invalid)).thenAnswer(
        (_) async => const Err(SendStoredTransactionInvalidFailure()),
      );

      final result = await WatchPendingBitcoinTransactionsUsecase(
        repository,
        validate,
      ).execute('wallet-id').first;

      expect(result, isA<Ok<PendingBitcoinTransactionSnapshot, SendFailure>>());
      final snapshot =
          (result as Ok<PendingBitcoinTransactionSnapshot, SendFailure>).value;
      expect(snapshot.transactions, [valid]);
      expect(snapshot.invalidCount, 1);
    },
  );
}

PendingBitcoinTransaction _draft(String id) => PendingBitcoinTransaction(
  id: id,
  walletId: 'wallet-id',
  stage: PendingBitcoinTransactionStage.draft,
  recipient: '',
  amount: '',
  amountCurrencyCode: '',
  sendMax: false,
  feeSelection: FeeSelection.fastest,
  replaceByFee: true,
  createdAt: DateTime.utc(2026, 8, 14),
  updatedAt: DateTime.utc(2026, 8, 14),
);
