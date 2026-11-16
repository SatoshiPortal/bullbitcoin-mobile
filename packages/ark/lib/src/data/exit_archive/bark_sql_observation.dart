import '../../../ark.dart';

/// Process/connection-local change hint, never persisted as a coverage revision.
final class BarkSqlSourceToken {
  final int epochConn;
  final int dataVersion;
  const BarkSqlSourceToken(this.epochConn, this.dataVersion);
  @override
  bool operator ==(Object other) =>
      other is BarkSqlSourceToken &&
      epochConn == other.epochConn &&
      dataVersion == other.dataVersion;
  @override
  int get hashCode => Object.hash(epochConn, dataVersion);
}

/// Encoded opaque cells are immutable strings, including copied BLOB bytes.
/// Never expose these secret-bearing values in snapshots, failures or toString.
final class BarkSqlOpaqueRow {
  final String sourceTable;
  final String rowKey;
  final String payload;
  final String digest;
  const BarkSqlOpaqueRow(
    this.sourceTable,
    this.rowKey,
    this.payload,
    this.digest,
  );
}

final class BarkSqlObservation {
  final ArkAccountId account;
  final BarkSqlSourceToken sourceToken;
  final DateTime observedAtUTC;
  final List<BarkSqlOpaqueRow> rows;
  BarkSqlObservation(
    this.account,
    this.sourceToken,
    this.observedAtUTC,
    List<BarkSqlOpaqueRow> rows,
  ) : rows = List.unmodifiable(rows);
}
