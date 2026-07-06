import 'package:bb_mobile/core/transactions/domain/domain_errors.dart';
import 'package:bb_mobile/core/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/core/transactions/domain/transaction_port.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/application/build_reviewable_transaction_usecase.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/reviewable_transaction.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/transaction_review_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTransactionPort extends Mock implements TransactionPort {}

class _MockTransaction extends Mock implements Transaction {}

class _MockTxInput extends Mock implements TxInput {}

class _MockTxOutput extends Mock implements TxOutput {}

void main() {
  late _MockTransactionPort port;
  late BuildReviewableTransactionUsecase usecase;

  setUp(() {
    port = _MockTransactionPort();
    usecase = BuildReviewableTransactionUsecase(transactionPort: port);
  });

  Transaction txSpending(String parentTxId, int vout) {
    final input = _MockTxInput();
    when(() => input.previousTxId).thenReturn(parentTxId);
    when(() => input.previousVout).thenReturn(vout);
    final tx = _MockTransaction();
    when(() => tx.inputs).thenReturn([input]);
    return tx;
  }

  group('BuildReviewableTransactionUsecase', () {
    test(
      'maps a TransactionPort fetch failure to a sanitized review failure '
      'without leaking the raw reason',
      () async {
        final tx = txSpending('parenttxid', 0);
        when(() => port.fetch(txid: any(named: 'txid'))).thenThrow(
          const TransactionPortError.fetchFailed(
            txid: 'parenttxid',
            message: 'electrum: connection reset by 1.2.3.4',
          ),
        );

        final result = await usecase.execute(tx);

        expect(
          result,
          isA<Err<ReviewableTransaction, TransactionReviewFailure>>(),
        );
        final failure =
            (result as Err<ReviewableTransaction, TransactionReviewFailure>)
                .failure;
        expect(failure, isA<TransactionReviewFetchFailure>());
        expect((failure as TransactionReviewFetchFailure).txid, 'parenttxid');
        // The raw electrum reason is logged-only, never surfaced as the txid.
        expect(failure.txid, isNot(contains('electrum')));
      },
    );

    test('returns an input-resolution failure when the vout is out of range', () async {
      final tx = txSpending('parenttxid', 5);
      final parentTx = _MockTransaction();
      when(() => parentTx.outputs).thenReturn(const []);
      when(
        () => port.fetch(txid: any(named: 'txid')),
      ).thenAnswer((_) async => parentTx);

      final result = await usecase.execute(tx);

      expect(
        (result as Err<ReviewableTransaction, TransactionReviewFailure>)
            .failure,
        isA<TransactionReviewInputResolutionFailure>(),
      );
    });

    test('resolves the input value and returns Ok on success', () async {
      final tx = txSpending('parenttxid', 0);
      final parentOutput = _MockTxOutput();
      when(() => parentOutput.valueSat).thenReturn(4200);
      when(() => parentOutput.address).thenReturn('bc1qexample');
      final parentTx = _MockTransaction();
      when(() => parentTx.outputs).thenReturn([parentOutput]);
      when(
        () => port.fetch(txid: any(named: 'txid')),
      ).thenAnswer((_) async => parentTx);

      final result = await usecase.execute(tx);

      expect(
        result,
        isA<Ok<ReviewableTransaction, TransactionReviewFailure>>(),
      );
      final reviewable =
          (result as Ok<ReviewableTransaction, TransactionReviewFailure>).value;
      expect(reviewable.resolvedInputs, hasLength(1));
      expect(reviewable.resolvedInputs.first.valueSat, 4200);
    });
  });
}
