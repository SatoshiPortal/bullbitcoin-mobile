import 'package:swaps/src/log.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/swap_repository.dart';

/// One log line enumerating every stored swap, so a single user log export
/// shows exactly which local state a stuck swap carries. Full detail only
/// for unresolved swaps; settled swaps contribute a count (address/txid
/// linkage stays out of routine exports).
class LogSwapCensusUsecase {
  final SwapRepository _swapRepository;

  LogSwapCensusUsecase({required this._swapRepository});

  Future<void> execute() async {
    try {
      final swaps = await _swapRepository.all();
      final unresolved = [
        for (final s in swaps)
          if (!s.status.isTerminal ||
              (s.status == SwapStatus.completed &&
                  switch (s) {
                    LnReceiveSwap() =>
                      s.receiveTxid == null && !s.wasDirectPayment,
                    ChainSwap() =>
                      s.receiveTxid == null && s.refundTxid == null,
                    LnSendSwap() => false,
                  }))
            s,
      ];
      final detail = unresolved.isEmpty
          ? ''
          : ': ${unresolved.map(_describe).join(' | ')}';
      swapsLog.fine(
        '[SwapCensus] ${swaps.length} stored swaps, '
        '${unresolved.length} unresolved$detail',
      );
      await swapsLog.flush();
    } catch (e) {
      swapsLog.warning('[SwapCensus] failed: $e');
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
    return '${s.id} ${s.type.name} ${s.status.name}'
        ' keyIndex=${s.keyIndex}'
        ' send=${send ?? '-'} recv=${recv ?? '-'} refund=${refund ?? '-'}';
  }
}
