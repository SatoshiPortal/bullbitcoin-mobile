import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';

/// The last authenticated remote head, durable across app restarts.
///
/// A routine publication conditional-stores straight against this instead of
/// re-fetching the head first (spec 17 and F7). [ciphertextSha256] is null when
/// the remote object is absent, which is how a delete tombstone is represented.
final class WalletBackupRemoteCheckpoint {
  final int generation;
  final String etag;
  final String? ciphertextSha256;

  WalletBackupRemoteCheckpoint({
    required this.generation,
    required this.etag,
    required this.ciphertextSha256,
  }) {
    if (generation <= 0 ||
        !isWalletBackupHash(etag) ||
        (ciphertextSha256 != null && !isWalletBackupHash(ciphertextSha256))) {
      throw ArgumentError('Invalid backup checkpoint');
    }
  }

  bool get found => ciphertextSha256 != null;

  bool sameObjectAs(WalletBackupRemoteCheckpoint other) =>
      generation == other.generation &&
      etag == other.etag &&
      ciphertextSha256 == other.ciphertextSha256;
}

/// A fetched head: its durable identity plus the bytes it carries.
final class WalletBackupRemoteHead {
  /// Null only before anything was ever stored for this account.
  final WalletBackupRemoteCheckpoint? checkpoint;
  final WalletBackupCiphertext? ciphertext;

  const WalletBackupRemoteHead._(this.checkpoint, this.ciphertext);

  int get generation => checkpoint?.generation ?? 0;
  String? get etag => checkpoint?.etag;
  String? get ciphertextSha256 => checkpoint?.ciphertextSha256;
  bool get found => ciphertext != null;

  factory WalletBackupRemoteHead.absent({
    required int generation,
    required String? etag,
  }) {
    if ((generation == 0) != (etag == null)) {
      throw ArgumentError('Invalid absent backup head');
    }
    return WalletBackupRemoteHead._(
      etag == null
          ? null
          : WalletBackupRemoteCheckpoint(
              generation: generation,
              etag: etag,
              ciphertextSha256: null,
            ),
      null,
    );
  }

  factory WalletBackupRemoteHead.present({
    required int generation,
    required String etag,
    required WalletBackupCiphertext ciphertext,
    required String ciphertextSha256,
  }) => WalletBackupRemoteHead._(
    WalletBackupRemoteCheckpoint(
      generation: generation,
      etag: etag,
      ciphertextSha256: ciphertextSha256,
    ),
    ciphertext,
  );
}

bool isWalletBackupHash(String? value) =>
    value != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
