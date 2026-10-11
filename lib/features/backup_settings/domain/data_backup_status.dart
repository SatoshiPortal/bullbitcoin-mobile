import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';

final class DataBackupStatus {
  final WalletBackupControl control;
  final DateTime? lastSuccessAt;
  final WalletBackupPublication? publication;
  final bool publishing;
  final BackupSettingsFailure? failure;

  const DataBackupStatus({
    required this.control,
    this.lastSuccessAt,
    this.publication,
    this.publishing = false,
    this.failure,
  });

  bool get isUpToDate =>
      control.enabled == true &&
      !control.recoveryIncomplete &&
      !publishing &&
      failure == null &&
      lastSuccessAt != null &&
      (publication == WalletBackupPublication.published ||
          publication == WalletBackupPublication.upToDate);
}
