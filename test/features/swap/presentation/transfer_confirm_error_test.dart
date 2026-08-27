import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_confirm_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shows a localized build error when transaction construction fails', () {
    final message = transferConfirmErrorMessage(
      buildTransactionException: BuildTransactionException('relay floor'),
      swapFailureMessage: null,
      buildFailureMessage: 'Build Failed',
    );

    expect(message, 'Build Failed');
  });
}
