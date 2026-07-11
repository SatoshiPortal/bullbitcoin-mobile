import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';

/// One timestamped line in the SP notifications debug console.
class SpNotifLogLine {
  final DateTime time;
  final String text;

  const SpNotifLogLine({required this.time, required this.text});
}

/// One-line, human-readable rendering of an [SpNotification] for the debug
/// console. ElectrumTx shows the sub-account kind, txid, amount and height so a
/// missing taproot electrum push is visible.
String formatSpNotification(SpNotification n) {
  switch (n) {
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
    case SpScanFailed(:final message):
      return 'ScanFailed: $message';
    case SpNewOutput(:final outpoint, :final amountSat):
      return 'NewOutput $outpoint ${amountSat}sat';
    case SpOutputSpent(:final outpoint):
      return 'OutputSpent $outpoint';
    case SpElectrumTx(:final kind, :final txid, :final amountSat, :final height):
      final at = height == null ? '' : ' @$height';
      return 'ElectrumTx ${kind.name} $txid ${amountSat}sat$at';
    case SpBackendOffline():
      return 'BackendOffline';
  }
}
