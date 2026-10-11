final class WalletBackupCheckpoint {
  final int generation;
  final String etag;
  final String ciphertextHash;

  WalletBackupCheckpoint({
    required this.generation,
    required this.etag,
    required this.ciphertextHash,
  }) {
    if (generation < 1 ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(etag) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(ciphertextHash)) {
      throw const FormatException('Invalid backup checkpoint');
    }
  }
}

final class WalletBackupState {
  final String identity;
  final bool? enabled;
  final WalletBackupCheckpoint? checkpoint;
  final String? confirmedContentHash;
  final DateTime? lastSuccessAt;
  final bool recoveryIncomplete;

  WalletBackupState({
    required this.identity,
    this.enabled,
    this.checkpoint,
    this.confirmedContentHash,
    this.lastSuccessAt,
    this.recoveryIncomplete = false,
  }) {
    final contentHash = confirmedContentHash;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(identity) ||
        (contentHash != null &&
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(contentHash)) ||
        (checkpoint == null &&
            (contentHash != null || lastSuccessAt != null))) {
      throw const FormatException('Invalid backup state');
    }
  }
}

final class WalletBackupControl {
  final bool? enabled;
  final bool recoveryIncomplete;

  const WalletBackupControl({this.enabled, this.recoveryIncomplete = false});
}
