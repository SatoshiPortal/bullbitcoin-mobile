import 'dart:typed_data';

import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

abstract interface class WalletBackupFileRepository {
  @useResult
  Future<Result<bool, BackupSettingsFailure>> save(WalletBackupExport export);

  @useResult
  Future<Result<Uint8List?, BackupSettingsFailure>> pick({
    required int maximumBytes,
  });
}
