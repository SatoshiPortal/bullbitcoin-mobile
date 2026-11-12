import 'package:bb_mobile/core/transactions/domain/entities/liquid_transaction.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/reviewable_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../reviewable_transaction_fixture.dart';

void main() {
  // Regression (Pixel 6a): a signed transaction edited to pay out more than
  // its inputs reviewed with an "Unknown" fee and no warning.
  test('flags a Bitcoin transaction whose outputs exceed its inputs', () {
    final review = bitcoinReview(inputSat: 25000, outputSat: 25300);

    expect(review.outputsExceedInputs, isTrue);
    expect(review.feeSat, isNull);
  });

  test('does not flag outputs equal to or below the inputs', () {
    expect(
      bitcoinReview(inputSat: 25000, outputSat: 25000).outputsExceedInputs,
      isFalse,
    );
    expect(
      bitcoinReview(inputSat: 25000, outputSat: 24800).outputsExceedInputs,
      isFalse,
    );
  });

  test('never flags a Liquid transaction', () {
    final review = ReviewableTransaction(
      transaction: const LiquidTransaction(
        txid: 'tx',
        version: 2,
        vsize: 100,
        weight: 400,
        locktime: 0,
        feeSat: 33,
        inputs: [],
        outputs: [],
      ),
      resolvedInputs: const [],
    );

    expect(review.outputsExceedInputs, isFalse);
  });
}
