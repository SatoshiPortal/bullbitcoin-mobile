import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';

enum SpHeaderValidationPhase { replay, initialSync }

/// A Silent Payments session event (scan progress, electrum push, backend
/// state). Domain mirror of the bwk `SpNotification` FFI union; the wire type
/// stays in `data/` behind `SpNotificationMapper`.
sealed class SpNotification {
  const SpNotification();
}

final class SpScanStarted extends SpNotification {
  final int from;
  final int to;
  const SpScanStarted(this.from, this.to);
}

final class SpScanReceiveProgress extends SpNotification {
  final int current;
  final int end;
  const SpScanReceiveProgress(this.current, this.end);
}

final class SpScanSpendProgress extends SpNotification {
  final int current;
  final int end;
  const SpScanSpendProgress(this.current, this.end);
}

final class SpScanCompleted extends SpNotification {
  const SpScanCompleted();
}

final class SpScanStopped extends SpNotification {
  const SpScanStopped();
}

final class SpScanFailed extends SpNotification {
  final String message;
  const SpScanFailed(this.message);
}

final class SpNewOutput extends SpNotification {
  final String outpoint;
  final BigInt amountSat;
  const SpNewOutput(this.outpoint, this.amountSat);
}

final class SpOutputSpent extends SpNotification {
  final String outpoint;
  const SpOutputSpent(this.outpoint);
}

final class SpBroadcasted extends SpNotification {
  final String txid;
  const SpBroadcasted(this.txid);
}

final class SpBroadcastFailed extends SpNotification {
  final String message;
  const SpBroadcastFailed(this.message);
}

final class SpElectrumTx extends SpNotification {
  final SpCoinSource kind;
  final String txid;
  final BigInt amountSat;
  final int? height;
  const SpElectrumTx({
    required this.kind,
    required this.txid,
    required this.amountSat,
    this.height,
  });
}

final class SpBackendOffline extends SpNotification {
  const SpBackendOffline();
}

final class SpPaymentHistoryUpdated extends SpNotification {
  const SpPaymentHistoryUpdated();
}

final class SpHeaderProgressStarted extends SpNotification {
  final SpHeaderValidationPhase phase;
  final int start;
  final int end;
  const SpHeaderProgressStarted({
    required this.phase,
    required this.start,
    required this.end,
  });
}

final class SpHeaderProgress extends SpNotification {
  final SpHeaderValidationPhase phase;
  final int current;
  final int end;
  const SpHeaderProgress({
    required this.phase,
    required this.current,
    required this.end,
  });
}

final class SpHeaderProgressCompleted extends SpNotification {
  final SpHeaderValidationPhase phase;
  const SpHeaderProgressCompleted(this.phase);
}

final class SpHeaderProgressFailed extends SpNotification {
  final SpHeaderValidationPhase phase;
  const SpHeaderProgressFailed(this.phase);
}
