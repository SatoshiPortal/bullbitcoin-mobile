enum BackupProviderType { googleDrive, iCloud, custom }

extension BackupProviderTypeX on BackupProviderType {
  String get name {
    switch (this) {
      case BackupProviderType.googleDrive:
        return 'Google Drive';
      case BackupProviderType.iCloud:
        return 'Apple iCloud';
      case BackupProviderType.custom:
        return 'Custom location';
    }
  }

  String get iconPath {
    switch (this) {
      case BackupProviderType.googleDrive:
        return 'assets/google_drive.png';
      case BackupProviderType.iCloud:
        return 'assets/icloud.png';
      case BackupProviderType.custom:
        return 'assets/custom_location.png';
    }
  }

  String get description {
    switch (this) {
      case BackupProviderType.googleDrive:
      case BackupProviderType.iCloud:
        return 'Quick & easy';
      case BackupProviderType.custom:
        return 'Take your time';
    }
  }
}
