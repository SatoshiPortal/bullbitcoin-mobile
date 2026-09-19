import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file_comparison.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

abstract interface class WalletBackupCodecRepository {
  @useResult
  Result<Set<WalletBackupDifference>, WalletBackupFailure> differences(
    WalletBackupSnapshot left,
    WalletBackupSnapshot right,
  );
  @useResult
  Result<String, WalletBackupFailure> encodeFile(
    WalletBackupSnapshot snapshot,
    BackupCredential credential, {
    required WalletBackupFileFormat format,
  });

  @useResult
  Result<WalletBackupFile, WalletBackupFailure> decodeFile(
    String source, {
    BackupCredential? credential,
  });

  @useResult
  Result<String, WalletBackupFailure> encode(WalletBackupSnapshot snapshot);
  @useResult
  Result<WalletBackupSnapshot, WalletBackupFailure> decode(String source);
  @useResult
  Result<String, WalletBackupFailure> contentHash(
    WalletBackupSnapshot snapshot,
  );
  @useResult
  Result<WalletBackupCiphertext, WalletBackupFailure> encrypt(
    WalletBackupSnapshot snapshot,
    BackupCredential credential,
  );
  @useResult
  Result<WalletBackupSnapshot, WalletBackupFailure> decrypt(
    WalletBackupCiphertext ciphertext,
    BackupCredential credential,
  );
  Stream<void> get changes;
  @useResult
  Future<Result<WalletBackupSnapshot, WalletBackupFailure>> capture(
    BackupCredential credential,
  );
}
