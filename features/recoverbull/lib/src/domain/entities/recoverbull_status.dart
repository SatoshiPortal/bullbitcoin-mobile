import 'package:meta/meta.dart';

@immutable
final class RecoverBullStatus {
  final DateTime? lastEncryptedBackupAt;
  final DateTime? lastVerifiedEncryptedBackupAt;
  final bool isKnown;

  const RecoverBullStatus({
    this.lastEncryptedBackupAt,
    this.lastVerifiedEncryptedBackupAt,
    this.isKnown = true,
  });

  bool get hasEncryptedBackup =>
      lastEncryptedBackupAt != null || lastVerifiedEncryptedBackupAt != null;

  bool get hasVerifiedEncryptedBackup => lastVerifiedEncryptedBackupAt != null;

  const RecoverBullStatus.initial()
    : lastEncryptedBackupAt = null,
      lastVerifiedEncryptedBackupAt = null,
      isKnown = true;

  const RecoverBullStatus.unavailable()
    : lastEncryptedBackupAt = null,
      lastVerifiedEncryptedBackupAt = null,
      isKnown = false;
}
