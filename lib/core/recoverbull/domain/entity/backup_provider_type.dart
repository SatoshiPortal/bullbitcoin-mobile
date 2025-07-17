import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';

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
        return Assets.misc.googleDrive.path;
      case BackupProviderType.iCloud:
        return Assets.misc.icloud.path;
      case BackupProviderType.custom:
        return Assets.misc.customLocation.path;
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
