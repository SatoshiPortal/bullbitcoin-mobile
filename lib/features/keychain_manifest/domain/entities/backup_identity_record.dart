import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';

enum BackupIdentityKind { artifact, server }

/// Public instructions for the two identities that are children of the words.
/// These facts are reconstructed from the current source, not stored twice.
final class BackupIdentityRecord {
  final String parentFingerprint;
  final String publicKey;
  final BackupIdentityKind kind;

  BackupIdentityRecord({
    required this.parentFingerprint,
    required this.publicKey,
    required this.kind,
  }) {
    if (!RegExp(r'^[0-9a-f]{8}$').hasMatch(parentFingerprint) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(publicKey)) {
      throw const FormatException('Invalid backup identity');
    }
  }

  factory BackupIdentityRecord.fromInstruction({
    required String parentFingerprint,
    required String publicKey,
    required List<String> derivationSteps,
  }) {
    if (derivationSteps.length != 2 ||
        derivationSteps.first != Bip85Reservations.backupWords.path) {
      throw const FormatException('Unsupported backup identity chain');
    }
    final kind = switch (derivationSteps.last) {
      Bip85Reservations.backupArtifactIdentityPath =>
        BackupIdentityKind.artifact,
      Bip85Reservations.backupServerIdentityPath => BackupIdentityKind.server,
      _ => throw const FormatException('Unsupported backup identity chain'),
    };
    return BackupIdentityRecord(
      parentFingerprint: parentFingerprint,
      publicKey: publicKey,
      kind: kind,
    );
  }

  List<String> get derivationSteps => switch (kind) {
    BackupIdentityKind.artifact =>
      Bip85Reservations.backupArtifactIdentityChain,
    BackupIdentityKind.server => Bip85Reservations.backupServerIdentityChain,
  };
}
