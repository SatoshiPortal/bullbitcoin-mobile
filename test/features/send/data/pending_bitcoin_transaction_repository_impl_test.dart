import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/data/models/pending_bitcoin_transaction_model.dart';
import 'package:bb_mobile/features/send/data/pending_bitcoin_transaction_datasource.dart';
import 'package:bb_mobile/features/send/data/pending_bitcoin_transaction_repository_impl.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPendingBitcoinTransactionDatasource extends Mock
    implements PendingBitcoinTransactionDatasource {}

void main() {
  test('maps an invalid stored policy selection to a typed failure', () async {
    final datasource = _MockPendingBitcoinTransactionDatasource();
    when(() => datasource.get('pending-id')).thenAnswer(
      (_) async => PendingBitcoinTransactionModel(
        id: 'pending-id',
        walletId: 'wallet-id',
        stage: 'needsSignatures',
        recipient: 'tb1qrecipient',
        amount: '50000',
        amountCurrencyCode: 'sats',
        sendMax: false,
        feeSelection: 'fastest',
        replaceByFee: true,
        selectedOutpoints: const {},
        policyChoices: const {
          'external:root': [-1],
        },
        psbt: 'cHNidP8=',
        createdAt: DateTime.utc(2026, 8, 14),
        updatedAt: DateTime.utc(2026, 8, 14),
      ),
    );

    final result = await PendingBitcoinTransactionRepositoryImpl(
      datasource,
    ).get('pending-id');

    expect(result, isA<Err<PendingBitcoinTransaction?, SendFailure>>());
    expect(
      (result as Err<PendingBitcoinTransaction?, SendFailure>).failure,
      isA<SendStoredTransactionInvalidFailure>(),
    );
  });

  test(
    'maps malformed custom fee storage to an invalid-record failure',
    () async {
      final datasource = _MockPendingBitcoinTransactionDatasource();
      when(() => datasource.get('pending-id')).thenAnswer(
        (_) async => PendingBitcoinTransactionModel(
          id: 'pending-id',
          walletId: 'wallet-id',
          stage: 'draft',
          recipient: '',
          amount: '',
          amountCurrencyCode: '',
          sendMax: false,
          feeSelection: 'custom',
          customFeeKind: 'unknown',
          customFeeValue: 1,
          replaceByFee: true,
          selectedOutpoints: const {},
          policyChoices: const {},
          createdAt: DateTime.utc(2026, 8, 14),
          updatedAt: DateTime.utc(2026, 8, 14),
        ),
      );

      final result = await PendingBitcoinTransactionRepositoryImpl(
        datasource,
      ).get('pending-id');

      expect(result, isA<Err<PendingBitcoinTransaction?, SendFailure>>());
      expect(
        (result as Err<PendingBitcoinTransaction?, SendFailure>).failure,
        isA<SendStoredTransactionInvalidFailure>(),
      );
    },
  );
}
