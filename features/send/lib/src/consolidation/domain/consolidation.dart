import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

/// UTXO count above which a Liquid wallet should be consolidated. Kept a bit
/// below the ~256 hard confidential-tx input limit so we warn the user before
/// a spend actually fails.
const int kLiquidConsolidationThreshold = 250;

sealed class ConsolidationStatusFailure extends Failure {
  const ConsolidationStatusFailure();
}

final class ConsolidationStatusUnavailable extends ConsolidationStatusFailure {
  const ConsolidationStatusUnavailable();
}

abstract interface class Consolidation {
  const factory Consolidation.open(Spend spend) = _Consolidation;

  @useResult
  Future<Result<bool, ConsolidationStatusFailure>> isRequired(String walletId);
}

final class _Consolidation implements Consolidation {
  final Spend _spend;

  const _Consolidation(this._spend);

  @override
  Future<Result<bool, ConsolidationStatusFailure>> isRequired(
    String walletId,
  ) async =>
      (await _spend.countLiquidCoins(walletId))
          .map((count) => count > kLiquidConsolidationThreshold)
          .mapErr((_) => const ConsolidationStatusUnavailable());
}
