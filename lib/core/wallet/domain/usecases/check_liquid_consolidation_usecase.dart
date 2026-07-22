import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';

/// UTXO count above which a Liquid wallet should be consolidated. Kept a bit
/// below the ~256 hard confidential-tx input limit so we warn the user before
/// a spend actually fails.
const int kLiquidConsolidationThreshold = 250;

class CheckLiquidConsolidationUsecase {
  final LiquidWalletRepository _repository;

  CheckLiquidConsolidationUsecase({
    required LiquidWalletRepository liquidWalletRepository,
  }) : _repository = liquidWalletRepository;

  /// The wallet's L-BTC UTXO count, or null if it couldn't be read.
  Future<int?> count({required String walletId}) async {
    try {
      return await _repository.getLbtcUtxoCount(walletId: walletId);
    } catch (_) {
      return null;
    }
  }

  /// Whether the wallet needs consolidating (count over the threshold).
  Future<bool> execute({required String walletId}) async {
    final utxoCount = await count(walletId: walletId);
    return utxoCount != null && utxoCount > kLiquidConsolidationThreshold;
  }
}
