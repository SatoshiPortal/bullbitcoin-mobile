import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/restored_swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class RestoreSwapsUsecase {
  final BoltzSwapRepository _swapRepository;
  final SettingsRepository _settingsRepository;

  RestoreSwapsUsecase({
    required this._swapRepository,
    required this._settingsRepository,
  });

  Future<List<RestorableSwap>> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      log.fine('SWAP_RESTORE: starting (testnet=$isTestnet)');

      final restored = await _swapRepository.restoreSwaps(isTestnet: isTestnet);

      final localSwaps = {
        for (final swap in await _swapRepository.getAllSwaps()) swap.id: swap,
      };

      final result = [
        for (final swap in restored)
          RestorableSwap(
            swap: swap,
            existsLocally: localSwaps.containsKey(swap.id),
            locallyUnresolved: switch (localSwaps[swap.id]) {
              null => false,
              final local => !_isLocallySettled(local),
            },
          ),
      ];
      for (final r in result) {
        final local = localSwaps[r.swap.id];
        log.fine(
          'SWAP_RESTORE: ${r.swap.id} ${r.swap.kind.name} '
          'recoverable=${r.swap.recoverable} '
          'local=${r.existsLocally}'
          '${local != null ? ' localStatus=${local.status.name} localUnresolved=${r.locallyUnresolved}' : ''} '
          '=> rescuable=${r.isRescuable}',
        );
      }
      log.fine(
        'SWAP_RESTORE: ${result.length} restored, '
        '${result.where((r) => r.isRescuable).length} rescuable',
      );
      await log.flush();
      return result;
    } catch (e) {
      log.warning('SWAP_RESTORE: failed: $e');
      throw RestoreSwapsException('$e');
    }
  }

  /// Whether the local row records a resolution we can trust. Mirrors the
  /// datasource's settled rules: a terminal status alone is not enough when
  /// funds were locked — there must be a proving txid (or an MRH direct
  /// payment) behind it.
  bool _isLocallySettled(Swap swap) {
    switch (swap.status) {
      case SwapStatus.completed:
        return switch (swap) {
          LnReceiveSwap() => swap.receiveTxid != null || swap.wasDirectPayment,
          ChainSwap() => swap.receiveTxid != null || swap.refundTxid != null,
          LnSendSwap() => true,
        };
      case SwapStatus.refunded:
        return true;
      case SwapStatus.expired:
      case SwapStatus.failed:
        return switch (swap) {
          LnSendSwap() => swap.sendTxid == null || swap.refundTxid != null,
          ChainSwap() => swap.sendTxid == null || swap.refundTxid != null,
          LnReceiveSwap() => true,
        };
      case SwapStatus.pending:
      case SwapStatus.paid:
      case SwapStatus.claimable:
      case SwapStatus.refundable:
      case SwapStatus.canCoop:
        return false;
    }
  }
}

class RestoreSwapsException extends BullException {
  RestoreSwapsException(super.message);
}
