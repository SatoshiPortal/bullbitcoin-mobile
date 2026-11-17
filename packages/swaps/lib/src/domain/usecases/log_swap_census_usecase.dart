import 'package:swaps/src/log.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/swap_store.dart';

/// One log line enumerating every stored swap, so a single user log export
/// shows exactly which local state a stuck swap carries. Full detail only
/// for unresolved swaps; settled swaps contribute a count (address/txid
/// linkage stays out of routine exports).
class LogSwapCensusUsecase {
  final SwapStore _store;

  const LogSwapCensusUsecase(this._store);

  Future<void> execute() async {
    try {
      final swaps = switch (await _store.all()) {
        Ok(:final value) => value,
        Err(:final failure) => throw SwapsCensusException('$failure'),
      };
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
    } on SwapsCensusException catch (e) {
      swapsLog.warning('[SwapCensus] failed: ${e.reason}');
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

class SwapsCensusException implements Exception {
  final String reason;

  const SwapsCensusException(this.reason);
}
