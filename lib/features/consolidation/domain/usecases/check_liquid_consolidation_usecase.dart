import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

/// UTXO count above which a Liquid wallet should be consolidated. Kept a bit
/// below the ~256 hard confidential-tx input limit so we warn the user before
/// a spend actually fails.
const int kLiquidConsolidationThreshold = 250;

class CheckLiquidConsolidationUsecase {
  final Spend _spend;

  const CheckLiquidConsolidationUsecase(this._spend);

  /// The wallet's L-BTC UTXO count, or null if it couldn't be read.
  Future<int?> count({required String walletId}) async =>
      switch (await _spend.countLiquidCoins(walletId)) {
        Ok(:final value) => value,
        Err() => null,
      };

  /// Whether the wallet needs consolidating (count over the threshold).
  Future<bool> execute({required String walletId}) async {
    final utxoCount = await count(walletId: walletId);
    return utxoCount != null && utxoCount > kLiquidConsolidationThreshold;
  }
}
