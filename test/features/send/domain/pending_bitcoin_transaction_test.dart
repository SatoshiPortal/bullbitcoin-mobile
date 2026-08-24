import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('allows incomplete drafts but rejects incomplete signing records', () {
    expect(
      () => _transaction(stage: PendingBitcoinTransactionStage.draft),
      returnsNormally,
    );
    expect(
      () => _transaction(stage: PendingBitcoinTransactionStage.needsSignatures),
      throwsArgumentError,
    );
    expect(
      () => _transaction(
        stage: PendingBitcoinTransactionStage.needsSignatures,
        psbt: 'cHNidP8=',
      ),
      throwsArgumentError,
    );
    expect(
      () => _transaction(
        stage: PendingBitcoinTransactionStage.needsSignatures,
        psbt: 'cHNidP8=',
        recipient: 'tb1qrecipient',
        amount: '0',
        amountCurrencyCode: 'sats',
      ),
      throwsArgumentError,
    );
  });

  test('requires a positive fee for a custom selection', () {
    expect(
      () => _transaction(
        stage: PendingBitcoinTransactionStage.draft,
        feeSelection: FeeSelection.custom,
      ),
      throwsArgumentError,
    );
    expect(
      () => _transaction(
        stage: PendingBitcoinTransactionStage.draft,
        feeSelection: FeeSelection.custom,
        customFee: NetworkFee.absolute(1),
      ),
      returnsNormally,
    );
  });
}

PendingBitcoinTransaction _transaction({
  required PendingBitcoinTransactionStage stage,
  String? psbt,
  String recipient = '',
  String amount = '',
  String amountCurrencyCode = '',
  FeeSelection feeSelection = FeeSelection.fastest,
  NetworkFee? customFee,
}) => PendingBitcoinTransaction(
  id: 'pending-id',
  walletId: 'wallet-id',
  stage: stage,
  recipient: recipient,
  amount: amount,
  amountCurrencyCode: amountCurrencyCode,
  sendMax: false,
  feeSelection: feeSelection,
  customFee: customFee,
  replaceByFee: true,
  psbt: psbt,
  createdAt: DateTime.utc(2026, 8, 14),
  updatedAt: DateTime.utc(2026, 8, 14),
);
