import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_head.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';

/// Public facts from one authenticated read; no credential is retained.
final class WalletBackupInspection {
  final String identity;
  final WalletBackupRemoteHead head;
  final WalletBackupSnapshot? snapshot;

  WalletBackupInspection({
    required this.identity,
    required this.head,
    required this.snapshot,
  }) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(identity) ||
        head.found != (snapshot != null)) {
      throw const FormatException('Inconsistent backup inspection');
    }
  }
}
