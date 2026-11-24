/// BIP329 record types.
enum BackupLabelType { tx, addr, pubkey, input, output, xpub }

/// Bitcoin records go into the BIP139 export; Liquid records into the
/// vendor item. A txid alone cannot tell the two chains apart.
enum BackupLabelChain { bitcoin, liquid }

/// One BIP329 record; coin freezes travel as `spendable` on outputs.
final class BackupLabelRecord {
  final BackupLabelChain chain;
  final BackupLabelType type;
  final String ref;
  final String? label;
  final String? origin;
  final bool? spendable;

  /// Wallet the record is attributed to; required for freezes so ownership
  /// is checked against that wallet only.
  final String? walletId;

  BackupLabelRecord({
    required this.chain,
    required this.type,
    required this.ref,
    this.label,
    this.origin,
    this.spendable,
    this.walletId,
  }) {
    if (ref.isEmpty) throw ArgumentError('Label reference must not be empty');
    if (spendable != null && type != BackupLabelType.output) {
      throw ArgumentError('Only outputs carry spendable');
    }
    if (spendable == false && walletId == null) {
      throw ArgumentError('A freeze must name its wallet');
    }
  }
}

/// Immutable capture of one group's labels at a point in time.
final class LabelsSnapshot {
  final List<BackupLabelRecord> records;

  /// Labels that belong to no wallet of any group: never reported as saved.
  final int unattributedCount;

  /// Stored rows that could not be read: a complete backup is never claimed.
  final int skippedCount;

  LabelsSnapshot({
    required List<BackupLabelRecord> records,
    required this.unattributedCount,
    required this.skippedCount,
  }) : records = List.unmodifiable(records);
}
