import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

abstract interface class WalletBackupSnapshotRepository {
  Stream<void> get changes;
  @useResult
  Future<Result<WalletBackupSnapshot, WalletBackupFailure>> capture(
    BackupCredential credential,
  );
}
