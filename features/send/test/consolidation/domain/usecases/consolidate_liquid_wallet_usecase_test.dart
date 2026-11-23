import 'package:send/src/consolidation/domain/consolidation.dart';
import 'package:send/src/consolidation/domain/usecases/consolidate_liquid_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

import '../../consolidation_spend.dart';

void main() {
  const walletId = 'liquid-wallet';
  late ConsolidationSpend spend;
  late ConsolidateLiquidWalletUsecase usecase;

  setUp(() {
    spend = ConsolidationSpend(walletId);
    usecase = ConsolidateLiquidWalletUsecase(spend);
  });

  test('checks the wallet above, at and below the threshold', () async {
    final check = Consolidation.open(spend);
    for (final offset in [-1, 0, 1]) {
      final count = kLiquidConsolidationThreshold + offset;
      spend.count = Ok(count);
      expect(
        await check.isRequired(walletId),
        isA<Ok<bool, ConsolidationStatusFailure>>().having(
          (result) => result.value,
          'value',
          offset > 0,
        ),
      );
    }
    spend.count = const Err(SpendUnavailableFailure());
    expect(
      await check.isRequired(walletId),
      isA<Err<bool, ConsolidationStatusFailure>>(),
    );
  });

  test('reviews the fee and submits that exact prepared value', () async {
    final result = await usecase.prepare(walletId: walletId);
    final preview =
        (result as Ok<ConsolidationPreview, ConsolidationFailure>).value;
    expect(preview.transactionCount, 2);
    expect(preview.totalFeeSat, 50);
    expect(
      await usecase.broadcast(preview),
      isA<Ok<List<String>, ConsolidationFailure>>().having(
        (result) => result.value,
        'txids',
        ['first', 'second'],
      ),
    );
    expect(spend.submitted.single, same(spend.prepared.single));
  });

  test('preparation refusal stays typed and does not submit', () async {
    spend.preparationFailure = const SpendUnavailableFailure();
    final result = await usecase.prepare(walletId: walletId);
    expect((result as Err).failure, isA<ConsolidationPreparationFailure>());
    expect(spend.submitted, isEmpty);
  });

  test('keeps the accepted batches and an uncertain outcome', () async {
    final result = await usecase.prepare(walletId: walletId);
    final preview =
        (result as Ok<ConsolidationPreview, ConsolidationFailure>).value;
    spend.submissionFailure = SpendConsolidationInterruptedFailure([
      'first',
    ], const SpendBroadcastOutcomeUnknownFailure());
    final submitted = await usecase.broadcast(preview);
    expect(
      (submitted as Err).failure,
      isA<ConsolidationSubmissionFailure>()
          .having((e) => e.acceptedTxids, 'accepted', ['first'])
          .having((e) => e.outcomeUnknown, 'unknown', true),
    );
  });
}
