final class KeychainManifestBackupState {
  final bool enabled;
  final bool dirty;
  final int dirtyRevision;
  final int? lastAttemptedAt;
  final int? lastSucceededAt;
  final int remoteGeneration;
  final String? remoteEtag;
  final String? contentHash;
  final int? unsupportedVersion;

  const KeychainManifestBackupState({
    required this.enabled,
    required this.dirty,
    required this.dirtyRevision,
    required this.lastAttemptedAt,
    required this.lastSucceededAt,
    required this.remoteGeneration,
    required this.remoteEtag,
    required this.contentHash,
    required this.unsupportedVersion,
  });
}
