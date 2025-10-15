import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';

enum VaultProvider {
  googleDrive,
  iCloud,
  customLocation;

  String get name {
    switch (this) {
      case VaultProvider.googleDrive:
        return 'Google Drive';
      case VaultProvider.iCloud:
        return 'Apple iCloud';
      case VaultProvider.customLocation:
        return 'Custom location';
    }
  }

  String get iconPath {
    switch (this) {
      case VaultProvider.googleDrive:
        return Assets.misc.googleDrive.path;
      case VaultProvider.iCloud:
        return Assets.misc.icloud.path;
      case VaultProvider.customLocation:
        return Assets.misc.customLocation.path;
    }
  }

  String get description {
    switch (this) {
      case VaultProvider.googleDrive:
      case VaultProvider.iCloud:
        return 'Quick & easy';
      case VaultProvider.customLocation:
        return 'Take your time';
    }
  }
}
