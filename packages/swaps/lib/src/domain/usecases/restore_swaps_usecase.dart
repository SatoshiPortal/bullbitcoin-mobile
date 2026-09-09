import 'package:swaps/src/log.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/entities/restored_swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/swap_repository.dart';

class RestoreSwapsUsecase {
  final SwapRepository _swapRepository;

  RestoreSwapsUsecase({required this._swapRepository});

  Future<Result<List<RestorableSwap>, SwapsFailure>> execute() async {
    try {
      final restored = await _swapRepository.restore();
      final localSwaps = {
        for (final swap in await _swapRepository.all()) swap.id: swap,
      };
      final result = [
        for (final swap in restored)
          RestorableSwap(
            swap: swap,
            existsLocally: localSwaps.containsKey(swap.id),
            locallyUnresolved: switch (localSwaps[swap.id]) {
              null => false,
              final local => !_isLocallySettled(
                local,
                onChainRecoverable: swap.recoverable,
              ),
            },
          ),
      ];
      for (final r in result) {
        final local = localSwaps[r.swap.id];
        swapsLog.fine(
          'SWAPS: restore ${r.swap.id} ${r.swap.kind.name} '
          'recoverable=${r.swap.recoverable} local=${r.existsLocally}'
          '${local != null ? ' localStatus=${local.status.name}' : ''} '
          '=> rescuable=${r.isRescuable}',
        );
      }
      await swapsLog.flush();
      return Ok(result);
    } catch (e) {
      swapsLog.warning('SWAPS: restore failed: $e');
      return Err(classifySwapsFailure(e));
    }
  }

  /// Whether the local row records a resolution we can trust: a terminal
  /// status alone is not enough when funds were locked — there must be a
  /// proving txid (or an MRH direct payment) behind it. [onChainRecoverable]
  /// is Boltz's restore verdict that a lockup exists and is unresolved: it
  /// beats the local "no sendTxid means nothing ever moved" inference, which
  /// is false when the app died between broadcast and store.
  bool _isLocallySettled(Swap swap, {required bool onChainRecoverable}) {
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
          LnSendSwap() =>
            swap.refundTxid != null ||
                (swap.sendTxid == null && !onChainRecoverable),
          ChainSwap() =>
            swap.refundTxid != null ||
                (swap.sendTxid == null && !onChainRecoverable),
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
