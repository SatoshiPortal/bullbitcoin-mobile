export 'src/data/database/legacy_recoverbull_permission.dart'
    show readLegacyRecoverBullPermission;
export 'src/data/database/recoverbull_cutover.dart' show RecoverBullCutover;
export 'src/data/database/recoverbull_retirement.dart'
    show RecoverBullRetirement;
export 'src/data/database/wallet_backup_import.dart'
    show importWalletBackupUsages;
export 'src/domain/recoverbull_failure.dart' show RecoverBullFailure;
export 'src/domain/wallet_backup_usage.dart' show WalletBackupUsage;

/// The endpoint seeded by the published legacy database migrations.
abstract final class RecoverBullLegacyDefaults {
  static const recoverbullUrl =
      'http://5m7enm5y77tdgmaf3d5xuwa5c7fjma7v5ljtwxu4q5jtq6b5utspmpyd.onion';
}
