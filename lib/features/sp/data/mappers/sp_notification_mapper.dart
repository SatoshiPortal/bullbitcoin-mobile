import 'package:bb_mobile/features/sp/data/mappers/sp_coin_mapper.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bull_sdk/bwk.dart' as bwk;

/// Maps the bwk FFI `SpNotification` union into the domain [SpNotification].
abstract final class SpNotificationMapper {
  static SpHeaderValidationPhase _headerPhaseToDomain(
    bwk.HeaderProgressPhase phase,
  ) => switch (phase) {
    bwk.HeaderProgressPhase.replay => SpHeaderValidationPhase.replay,
    bwk.HeaderProgressPhase.initialSync => SpHeaderValidationPhase.initialSync,
  };

  static SpNotification toDomain(bwk.SpNotification n) => switch (n) {
    bwk.SpNotification_ScanStarted(:final from, :final to) => SpScanStarted(
      from,
      to,
    ),
    bwk.SpNotification_ScanReceiveProgress(:final current, :final end) =>
      SpScanReceiveProgress(current, end),
    bwk.SpNotification_ScanSpendProgress(:final current, :final end) =>
      SpScanSpendProgress(current, end),
    bwk.SpNotification_ScanCompleted() => const SpScanCompleted(),
    bwk.SpNotification_ScanStopped() => const SpScanStopped(),
    bwk.SpNotification_ScanFailed(:final message) => SpScanFailed(message),
    bwk.SpNotification_NewOutput(:final outpoint, :final amountSat) =>
      SpNewOutput(outpoint, amountSat),
    bwk.SpNotification_OutputSpent(:final outpoint) => SpOutputSpent(outpoint),
    bwk.SpNotification_Broadcasted(:final txid) => SpBroadcasted(txid),
    bwk.SpNotification_BroadcastFailed(:final message) => SpBroadcastFailed(
      message,
    ),
    bwk.SpNotification_ElectrumTx(
      :final kind,
      :final txid,
      :final amountSat,
      :final height,
    ) =>
      SpElectrumTx(
        kind: SpCoinMapper.sourceToDomain(kind),
        txid: txid,
        amountSat: amountSat,
        height: height,
      ),
    bwk.SpNotification_BackendOffline() => const SpBackendOffline(),
    bwk.SpNotification_HeaderProgressStarted(
      :final phase,
      :final start,
      :final end,
    ) =>
      SpHeaderProgressStarted(
        phase: _headerPhaseToDomain(phase),
        start: start,
        end: end,
      ),
    bwk.SpNotification_HeaderProgress(
      :final phase,
      :final current,
      :final end,
    ) =>
      SpHeaderProgress(
        phase: _headerPhaseToDomain(phase),
        current: current,
        end: end,
      ),
    bwk.SpNotification_HeaderProgressCompleted(:final phase) =>
      SpHeaderProgressCompleted(_headerPhaseToDomain(phase)),
    bwk.SpNotification_HeaderProgressFailed(:final phase) =>
      SpHeaderProgressFailed(_headerPhaseToDomain(phase)),
    bwk.SpNotification_PaymentHistoryUpdated() =>
      const SpPaymentHistoryUpdated(),
  };
}
