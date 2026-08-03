import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/logger.dart';

/// Emits one log line enumerating every swap in local storage, so a single
/// user log export shows which local state (status / recorded txids) keeps a
/// swap out of `getOngoingSwaps`' watch set.
///
/// Called once from the app-startup sequence, after migrations have run, so
/// the read happens against a fully-opened database. The previous version
/// fired from `SwapWatcherService`'s constructor as fire-and-forget work and
/// raced SQLite init: the read never resolved, and because nothing awaited it
/// the census logged nothing at all — no count, not even its own error path.
///
/// Emitted at `fine`, not `info`: the logger deliberately drops `Level.INFO`
/// records from the on-disk file, so an `info` census never reaches a shared
/// log. One line rather than one-per-swap, because this lands in every
/// user's export on every launch.
class LogSwapCensusUsecase {
  final BoltzSwapRepository _swapRepository;

  LogSwapCensusUsecase({required BoltzSwapRepository boltzSwapRepository})
    : _swapRepository = boltzSwapRepository;

  Future<void> execute() async {
    try {
      final swaps = await _swapRepository.getAllSwaps();
      final detail = swaps.isEmpty
          ? ''
          : ': ${swaps.map(_describe).join(' | ')}';
      log.fine('[SwapCensus] ${swaps.length} stored swaps$detail');
      // `fine` records are only flushed opportunistically — the logger
      // forces a flush at SEVERE and above — so without this the census can
      // sit in the sink buffer and be lost to the force-restart a user does
      // when collecting clean logs.
      await log.flush();
    } catch (e) {
      // Diagnostics must never break startup.
      log.warning('[SwapCensus] failed: $e');
    }
  }

  String _describe(Swap s) {
    final send = switch (s) {
      LnSendSwap(:final sendTxid) => sendTxid,
      ChainSwap(:final sendTxid) => sendTxid,
      _ => null,
    };
    final recv = switch (s) {
      LnReceiveSwap(:final receiveTxid) => receiveTxid,
      ChainSwap(:final receiveTxid) => receiveTxid,
      _ => null,
    };
    final refund = switch (s) {
      LnSendSwap(:final refundTxid) => refundTxid,
      ChainSwap(:final refundTxid) => refundTxid,
      _ => null,
    };
    final refundAddr = switch (s) {
      LnSendSwap(:final refundAddress) => refundAddress,
      ChainSwap(:final refundAddress) => refundAddress,
      _ => null,
    };
    return '${s.id} ${s.type.name} ${s.status.name}'
        ' keyIndex=${s.keyIndex}'
        ' send=${send ?? '-'} recv=${recv ?? '-'} refund=${refund ?? '-'}'
        ' refundAddr=${refundAddr ?? '-'}'
        ' completedAt=${s.completionTime?.toIso8601String() ?? '-'}';
  }
}
