import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

abstract interface class WalletBackupFileRepository {
  @useResult
  Future<Result<String?, WalletBackupFailure>> pick();

  @useResult
  Future<Result<bool, WalletBackupFailure>> save(
    String source, {
    required WalletBackupFileFormat format,
  });
}
