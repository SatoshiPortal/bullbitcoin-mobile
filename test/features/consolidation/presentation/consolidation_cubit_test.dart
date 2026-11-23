import 'package:bb_mobile/features/consolidation/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/features/consolidation/domain/usecases/consolidate_liquid_wallet_usecase.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_cubit.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

import '../consolidation_spend.dart';

void main() {
  const walletId = 'wallet-1';
  late ConsolidationSpend spend;
  late ConsolidationCubit cubit;

  setUp(() {
    spend = ConsolidationSpend(walletId);
    cubit = ConsolidationCubit(
      walletId: walletId,
      consolidateLiquidWalletUsecase: ConsolidateLiquidWalletUsecase(spend),
      checkLiquidConsolidationUsecase: CheckLiquidConsolidationUsecase(spend),
    );
    addTearDown(cubit.close);
  });

  test(
    'loads count and preview, and only submits the reviewed batch once',
    () async {
      spend.count = const Ok(9);
      await cubit.load();
      expect(cubit.state.utxoCount, 9);
      expect(cubit.state.feeSat, 50);
      expect(cubit.state.transactionCount, 2);
      await Future.wait([cubit.consolidate(), cubit.consolidate()]);
      expect(cubit.state.status, ConsolidationStatus.success);
      expect(spend.submitted.single, same(spend.prepared.single));
    },
  );

  test('keeps the count when preparation fails', () async {
    spend.count = const Ok(9);
    spend.preparationFailure = const SpendUnavailableFailure();
    await cubit.load();
    expect(cubit.state.utxoCount, 9);
    expect(cubit.state.preview, isNull);
    expect(cubit.state.feeSat, isNull);
  });

  test('keeps preview when count is unavailable', () async {
    spend.count = const Err(SpendUnavailableFailure());
    await cubit.load();
    expect(cubit.state.utxoCount, isNull);
    expect(cubit.state.feeSat, 50);
  });

  test('definitive partial failure clears the preview before retry', () async {
    spend.submissionFailure = SpendConsolidationInterruptedFailure(
      ['first'],
      const SpendBroadcastRejectedFailure(SpendBroadcastRejection.nodeRejected),
    );
    await cubit.load();
    await cubit.consolidate();
    expect(cubit.state.status, ConsolidationStatus.failed);
    expect(cubit.state.preview, isNull);
    expect(cubit.acceptedBeforeFailure, ['first']);
    spend.submissionFailure = null;
    await cubit.consolidate();
    expect(spend.prepared.length, 2);
    expect(spend.submitted.length, 1);
    await cubit.consolidate();
    expect(cubit.state.status, ConsolidationStatus.success);
    expect(spend.prepared.length, 2);
    expect(spend.submitted.last, same(spend.prepared.last));
    expect(spend.submitted.first, isNot(same(spend.submitted.last)));
  });

  test('does not build or submit again after an uncertain outcome', () async {
    spend.submissionFailure = SpendConsolidationInterruptedFailure([
      'first',
    ], const SpendBroadcastOutcomeUnknownFailure());
    await cubit.load();
    await cubit.consolidate();
    expect(cubit.state.status, ConsolidationStatus.failed);
    expect(cubit.canSubmit, isFalse);
    expect(cubit.acceptedBeforeFailure, ['first']);
    await cubit.consolidate();
    expect(spend.prepared.length, 1);
    expect(spend.submitted.length, 1);
  });
}
