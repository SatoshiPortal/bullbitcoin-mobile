/// What became of one candidate descriptor backup.
///
/// A lookup returns records nobody has vouched for, so most of these are
/// ordinary: a record filed under a shared token belongs to someone else, and
/// failing to open it is the expected outcome, not an error.
enum VaultRecoveryStatus {
  /// The vault was not on this device and now is, watch only unless a local
  /// key happened to match.
  imported,

  /// The vault was already here, so nothing changed.
  alreadyPresent,

  /// This key does not open that record, or the bytes are damaged.
  undecryptable,

  /// It opened, but what came out is not a vault this app can rebuild.
  unsupported,
}

final class VaultRecoveryOutcome {
  final VaultRecoveryStatus status;

  /// The wallet the vault now lives in, for the two outcomes that have one.
  final String? walletId;

  const VaultRecoveryOutcome(this.status, {this.walletId});
}

/// What a whole recovery attempt found, one outcome per candidate.
///
/// [incomplete] means the server could not prove it returned every record, so
/// an empty or partial result must be shown as a search that did not finish
/// rather than as proof that nothing was published.
final class VaultRecoveryResult {
  final List<VaultRecoveryOutcome> outcomes;
  final bool incomplete;

  VaultRecoveryResult({
    required Iterable<VaultRecoveryOutcome> outcomes,
    required this.incomplete,
  }) : outcomes = List.unmodifiable(outcomes);

  Iterable<VaultRecoveryOutcome> get recovered => outcomes.where(
    (outcome) =>
        outcome.status == VaultRecoveryStatus.imported ||
        outcome.status == VaultRecoveryStatus.alreadyPresent,
  );
}
