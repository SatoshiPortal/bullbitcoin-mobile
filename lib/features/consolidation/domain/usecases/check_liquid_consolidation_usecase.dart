import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

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
    return utxoCount != null && utxoCount > liquidConsolidationThreshold;
  }
}
