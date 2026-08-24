// Behavioral check for the audit claim on the transaction-list error surface
// (issue #2665 fix).
//
// Measured outcome: `Failure` does not override `toString()`, so the raw
// reason kept in `logMessage` never reaches the screen — there is no leak.
// What the screen used to render was `Instance of
// 'TransactionAggregationFailure'`; `transactions_screen.dart` now renders a
// localized message instead and no longer interpolates the failure.
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the failure never carries its raw reason into a rendered string', () {
    const failure = TransactionAggregationFailure(
      'DioException: https://api.example.com/orders?token=SECRET-TOKEN-123',
    );

    expect(failure.toString(), isNot(contains('SECRET-TOKEN-123')));
    expect(failure.logMessage, contains('SECRET-TOKEN-123'));
  });
}
