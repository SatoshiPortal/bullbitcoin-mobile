import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';

/// Authenticated identity of the remote object observed during recovery.
///
/// Ciphertext is deliberately excluded: recovery only needs a stable token
/// that detects replacement, deletion, or creation of the remote object.
final class WalletBackupRemoteIdentity {
  final bool found;
  final int generation;
  final String? etag;
  final String? ciphertextSha256;

  WalletBackupRemoteIdentity({
    required this.found,
    required this.generation,
    required this.etag,
    required this.ciphertextSha256,
  }) {
    if (generation < 0 ||
        (found &&
            (generation == 0 ||
                !_isHash(etag) ||
                !_isHash(ciphertextSha256))) ||
        (!found &&
            (ciphertextSha256 != null ||
                (generation == 0 ? etag != null : !_isHash(etag))))) {
      throw ArgumentError('wallet backup remote identity is inconsistent');
    }
  }

  factory WalletBackupRemoteIdentity.fromHead(WalletBackupRemoteHead head) =>
      WalletBackupRemoteIdentity(
        found: head.found,
        generation: head.generation,
        etag: head.etag,
        ciphertextSha256: head.ciphertextSha256,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletBackupRemoteIdentity &&
          found == other.found &&
          generation == other.generation &&
          etag == other.etag &&
          ciphertextSha256 == other.ciphertextSha256;

  @override
  int get hashCode => Object.hash(found, generation, etag, ciphertextSha256);
}

bool _isHash(String? value) =>
    value != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
