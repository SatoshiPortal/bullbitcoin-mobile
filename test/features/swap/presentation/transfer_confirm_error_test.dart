import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_confirm_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const unavailable = 'Selected coins unavailable';
  const insufficient = 'Selected coins insufficient';
  const changed = 'Transaction changed';

  test('shows a localized build error when transaction construction fails', () {
    final message = transferConfirmErrorMessage(
      buildTransactionException: BuildTransactionException('relay floor'),
      swapFailureMessage: null,
      buildFailureMessage: 'Build Failed',
      selectedCoinsUnavailableMessage: 'Selected coins unavailable',
      selectedCoinsInsufficientMessage: insufficient,
      transactionChangedMessage: 'Transaction changed',
    );

    expect(message, 'Build Failed');
  });

  test('maps selected coins unavailable to its localized message', () {
    expect(
      transferConfirmErrorMessage(
        buildTransactionException: BuildTransactionException(
          selectedCoinsUnavailableCode,
        ),
        swapFailureMessage: null,
        buildFailureMessage: 'Build Failed',
        selectedCoinsUnavailableMessage: unavailable,
        selectedCoinsInsufficientMessage: insufficient,
        transactionChangedMessage: changed,
      ),
      unavailable,
    );
  });

  test('maps selected coins insufficient to its localized message', () {
    expect(
      transferConfirmErrorMessage(
        buildTransactionException: BuildTransactionException(
          selectedCoinsInsufficientCode,
        ),
        swapFailureMessage: null,
        buildFailureMessage: 'Build Failed',
        selectedCoinsUnavailableMessage: unavailable,
        selectedCoinsInsufficientMessage: insufficient,
        transactionChangedMessage: changed,
      ),
      insufficient,
    );
  });

  test('maps transaction rebuild failure to its localized message', () {
    expect(
      transferConfirmErrorMessage(
        buildTransactionException: BuildTransactionException(
          transactionRebuildFailedCode,
        ),
        swapFailureMessage: null,
        buildFailureMessage: 'Build Failed',
        selectedCoinsUnavailableMessage: unavailable,
        selectedCoinsInsufficientMessage: insufficient,
        transactionChangedMessage: changed,
      ),
      changed,
    );
  });

  test('keeps unknown build errors generic', () {
    expect(
      transferConfirmErrorMessage(
        buildTransactionException: BuildTransactionException('unknown'),
        swapFailureMessage: null,
        buildFailureMessage: 'Build Failed',
        selectedCoinsUnavailableMessage: unavailable,
        selectedCoinsInsufficientMessage: insufficient,
        transactionChangedMessage: changed,
      ),
      'Build Failed',
    );
  });
}
