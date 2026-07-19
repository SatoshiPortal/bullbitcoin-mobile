/// A completed coinjoin, persisted so the History tab survives restarts.
class JoinstrHistoryEntry {
  final int amountSat;
  final String txId;
  final String relay;
  final int completedAtUnixSec;

  const JoinstrHistoryEntry({
    required this.amountSat,
    required this.txId,
    required this.relay,
    required this.completedAtUnixSec,
  });

  Map<String, dynamic> toJson() => {
    'amountSat': amountSat,
    'txId': txId,
    'relay': relay,
    'completedAtUnixSec': completedAtUnixSec,
  };

  /// Returns null for an entry that cannot be decoded, so one corrupt record
  /// does not take the whole history down with it.
  static JoinstrHistoryEntry? fromJson(Map<String, dynamic> json) {
    final amountSat = json['amountSat'];
    final txId = json['txId'];
    final relay = json['relay'];
    final completedAt = json['completedAtUnixSec'];
    if (amountSat is! int ||
        txId is! String ||
        relay is! String ||
        completedAt is! int) {
      return null;
    }
    return JoinstrHistoryEntry(
      amountSat: amountSat,
      txId: txId,
      relay: relay,
      completedAtUnixSec: completedAt,
    );
  }
}
