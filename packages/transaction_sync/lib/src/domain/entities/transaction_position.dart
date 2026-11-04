sealed class TransactionPosition {
  const TransactionPosition();
}

final class AnchoredPosition extends TransactionPosition {
  final String blockHash;
  final int height;
  final DateTime time;
  const AnchoredPosition(this.blockHash, this.height, this.time);
}

final class SourceReportedConfirmedPosition extends TransactionPosition {
  final int height;
  final DateTime? time;
  const SourceReportedConfirmedPosition(this.height, this.time);
}

final class UnconfirmedPosition extends TransactionPosition {
  final DateTime firstSeen;
  final DateTime lastSeen;
  const UnconfirmedPosition(this.firstSeen, this.lastSeen);
}

final class ConflictedPosition extends TransactionPosition {
  final String? replacingTxid;
  const ConflictedPosition(this.replacingTxid);
}

final class EvictedPosition extends TransactionPosition {
  final DateTime lastSeen;
  const EvictedPosition(this.lastSeen);
}

final class UnknownPosition extends TransactionPosition {
  const UnknownPosition();
}
