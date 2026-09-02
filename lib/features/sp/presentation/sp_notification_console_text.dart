import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';

/// One-line rendering of an [SpNotification] for the debug console. ElectrumTx
/// shows the sub-account kind, txid, amount and height so a missing taproot
/// electrum push is visible. Developer text, never localized.
extension SpNotificationConsoleText on SpNotification {
  String get consoleText {
    switch (this) {
      case SpScanStarted(:final from, :final to):
        return 'ScanStarted $from -> $to';
      case SpScanReceiveProgress(:final current, :final end):
        return 'ScanReceiveProgress $current / $end';
      case SpScanSpendProgress(:final current, :final end):
        return 'ScanSpendProgress $current / $end';
      case SpScanCompleted():
        return 'ScanCompleted';
      case SpScanStopped():
        return 'ScanStopped';
      case SpScanFailed(:final failure):
        return 'ScanFailed: ${failure.logMessage}';
      case SpNewOutput(:final outpoint, :final amountSat):
        return 'NewOutput $outpoint ${amountSat}sat';
      case SpOutputSpent(:final outpoint):
        return 'OutputSpent $outpoint';
      case SpBroadcasted(:final txid):
        return 'Broadcasted $txid';
      case SpBroadcastFailed(:final message):
        return 'BroadcastFailed: $message';
      case SpElectrumTx(
        :final kind,
        :final txid,
        :final amountSat,
        :final height,
      ):
        final at = height == null ? '' : ' @$height';
        return 'ElectrumTx ${kind.name} $txid ${amountSat}sat$at';
      case SpBackendOffline():
        return 'BackendOffline';
      case SpPaymentHistoryUpdated():
        return 'PaymentHistoryUpdated';
      case SpHeaderProgressStarted(:final phase, :final start, :final end):
        return 'HeaderProgressStarted ${phase.name} $start -> $end';
      case SpHeaderProgress(:final phase, :final current, :final end):
        return 'HeaderProgress ${phase.name} $current / $end';
      case SpHeaderProgressCompleted(:final phase):
        return 'HeaderProgressCompleted ${phase.name}';
      case SpHeaderProgressFailed(:final phase):
        return 'HeaderProgressFailed ${phase.name}';
    }
  }
}
