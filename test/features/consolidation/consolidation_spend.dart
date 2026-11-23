import 'package:bb_mobile/features/consolidation/domain/consolidation_config.dart';
import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';

class ConsolidationSpend extends FakeSpend {
  final String walletId;
  final List<PreparedLiquidConsolidation> prepared = [];
  final List<PreparedLiquidConsolidation> submitted = [];
  Result<int, SpendFailure> count = const Ok(1);
  SpendFailure? preparationFailure;
  SpendFailure? submissionFailure;

  ConsolidationSpend(this.walletId);

  @override
  Future<Result<int, SpendFailure>> countLiquidCoins(String walletId) async {
    expect(walletId, this.walletId);
    return count;
  }

  @override
  Future<Result<PreparedLiquidConsolidation, SpendFailure>>
  prepareLiquidConsolidation(
    String walletId, {
    required RelativeFee feeRate,
    required int highUtxoThreshold,
    required int maximumInputs,
  }) async {
    expect(walletId, this.walletId);
    expect(feeRate, NetworkFeeRelayPolicy.minRelay);
    expect(highUtxoThreshold, ConsolidationConfig.highUtxoThreshold);
    expect(maximumInputs, ConsolidationConfig.maximumInputs);
    if (preparationFailure case final failure?) return Err(failure);
    final value = SpendFixtures.consolidation(
      transactionCount: 2,
      totalFee: Sats.fromInt(50),
    );
    prepared.add(value);
    return Ok(value);
  }

  @override
  Future<Result<List<String>, SpendFailure>> submitLiquidConsolidation(
    PreparedLiquidConsolidation prepared,
  ) async {
    submitted.add(prepared);
    if (submissionFailure case final failure?) return Err(failure);
    return const Ok(['first', 'second']);
  }
}
