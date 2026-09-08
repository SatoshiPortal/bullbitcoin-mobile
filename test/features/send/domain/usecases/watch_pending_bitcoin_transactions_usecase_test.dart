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
    'keeps other rows when a transaction is invalid or temporarily unavailable',
    () async {
      final repository = _MockRepository();
      final validate = _MockValidatePendingBitcoinTransactionUsecase();
      final valid = _draft('valid');
      final invalid = _draft('invalid');
      final unavailable = _draft('unavailable').copyWith(
        stage: PendingBitcoinTransactionStage.needsSignatures,
        psbt: 'cHNidP8=',
        recipient: 'tb1qrecipient',
        amount: '1000',
        amountCurrencyCode: 'sats',
      );
      when(() => repository.watchWallet('wallet-id')).thenAnswer(
        (_) => Stream.value(
          Ok(
            PendingBitcoinTransactionSnapshot(
              transactions: [valid, invalid, unavailable],
              invalidCount: 0,
            ),
          ),
        ),
      );
      when(
        () => validate.execute(valid),
      ).thenAnswer((_) async => Ok((transaction: valid, details: null)));
      when(() => validate.execute(invalid)).thenAnswer(
        (_) async => const Err(SendStoredTransactionInvalidFailure()),
      );
      when(
        () => validate.execute(unavailable),
      ).thenAnswer((_) async => const Err(SendUnexpectedFailure('offline')));

      final result = await WatchPendingBitcoinTransactionsUsecase(
        repository,
        validate,
      ).execute('wallet-id').first;

      expect(result, isA<Ok<PendingBitcoinTransactionSnapshot, SendFailure>>());
      final snapshot =
          (result as Ok<PendingBitcoinTransactionSnapshot, SendFailure>).value;
      expect(snapshot.transactions.map((transaction) => transaction.id), [
        'valid',
        'unavailable',
      ]);
      expect(snapshot.transactions.last.isPolicyReady, isFalse);
      expect(snapshot.transactions.last.isValidationUnavailable, isTrue);
      expect(snapshot.transactions.first.isValidationUnavailable, isFalse);
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
