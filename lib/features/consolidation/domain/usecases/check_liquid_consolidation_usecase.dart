import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';

/// UTXO count above which a Liquid wallet should be consolidated. Kept a bit
/// below the ~256 hard confidential-tx input limit so we warn the user before
/// a spend actually fails.
const int kLiquidConsolidationThreshold = 250;

/// The wallet's confirmed, unfrozen L-BTC UTXO count (or null if it couldn't
/// be read) plus whether that count is over the consolidation threshold —
/// bundled together so callers needing either value (or both) still only
/// ever call the one `execute()` entry point, matching the codebase-wide
/// use-case convention of a single public entry method.
typedef LiquidConsolidationStatus = ({int? utxoCount, bool isRequired});

class CheckLiquidConsolidationUsecase {
  final LiquidWalletRepository _repository;
  final WalletUtxoRepository _utxoRepository;

  CheckLiquidConsolidationUsecase({
    required LiquidWalletRepository liquidWalletRepository,
    required WalletUtxoRepository walletUtxoRepository,
  }) : _repository = liquidWalletRepository,
       _utxoRepository = walletUtxoRepository;

  /// [LiquidConsolidationStatus.utxoCount] matches
  /// [ConsolidateLiquidWalletUsecase]'s own filtering exactly (confirmed,
  /// unfrozen), so the banner and the consolidation screen always agree on
  /// what "needs consolidating" means — a frozen UTXO doesn't count here
  /// either. [LiquidConsolidationStatus.isRequired] is that count compared
  /// against [kLiquidConsolidationThreshold].
  Future<LiquidConsolidationStatus> execute({required String walletId}) async {
    final utxoCount = await _confirmedUnfrozenUtxoCount(walletId: walletId);
    return (
      utxoCount: utxoCount,
      isRequired:
          utxoCount != null && utxoCount > kLiquidConsolidationThreshold,
    );
  }

  Future<int?> _confirmedUnfrozenUtxoCount({required String walletId}) async {
    try {
      final confirmedOutpoints = await _repository.getConfirmedLbtcOutpoints(
        walletId: walletId,
      );
      final frozenOutpoints = (await _utxoRepository.getAllFrozenOutpoints())
          .toSet();
      return confirmedOutpoints
          .where((o) => !frozenOutpoints.contains(o))
          .length;
    } catch (_) {
      return null;
    }
  }
}
