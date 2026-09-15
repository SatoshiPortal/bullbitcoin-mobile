import 'dart:typed_data';

/// Where a vault descriptor can be published.
///
/// The Bitcoin row the backup screen shows is not here: it is deferred, so
/// nothing can select it or record an attempt against it.
enum VaultBackupDestination { server, nostr }

/// How far a destination's publication got.
///
/// [sent] is an acknowledgement and [verified] is a read-back that produced the
/// same descriptor again; keeping them apart is what stops an accepted upload
/// from being shown as a proven recovery route.
enum VaultPublicationState { idle, pending, sent, verified, failed }

/// One vault's agreement with one destination, and the exact bytes it owes it.
final class VaultDescriptorPublication {
  final String walletId;
  final VaultBackupDestination destination;
  final bool enabled;

  /// The signed event or sealed artifact as it was first built. It is replaced
  /// only by an explicit prepare, so a retry cannot silently publish a second
  /// generation of the same descriptor.
  final Uint8List? artifact;
  final String? artifactSha256;
  final VaultPublicationState state;
  final int attempts;
  final DateTime updatedAt;

  VaultDescriptorPublication({
    required this.walletId,
    required this.destination,
    required this.enabled,
    required Uint8List? artifact,
    required this.artifactSha256,
    required this.state,
    required this.attempts,
    required DateTime updatedAt,
  }) : artifact = artifact?.asUnmodifiableView(),
       updatedAt = updatedAt.toUtc();

  /// Whether this destination still owes the vault a send.
  ///
  /// A destination that failed before it could even build its artifact is
  /// owed one too: building it is what the retry does. A row nobody has tried
  /// yet is not owed anything until the first publication runs.
  bool get outstanding =>
      enabled &&
      (state == VaultPublicationState.failed ||
          (artifact != null && state == VaultPublicationState.pending));
}
