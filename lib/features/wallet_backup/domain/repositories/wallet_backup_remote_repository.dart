import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote_head.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

abstract interface class WalletBackupRemoteRepository {
  @useResult
  Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> fetch(
    BackupCredential credential,
  );
  @useResult
  Future<Result<WalletBackupCheckpoint, WalletBackupFailure>> store(
    BackupCredential credential,
    WalletBackupCiphertext ciphertext, {
    required int generation,
    required String? expectedEtag,
  });
  @useResult
  Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> delete(
    BackupCredential credential, {
    required int generation,
    required String expectedEtag,
  });
}
