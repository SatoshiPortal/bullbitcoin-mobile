enum VaultProvider {
  googleDrive,
  iCloud,
  customLocation;

  String get iconPath {
    switch (this) {
      case VaultProvider.googleDrive:
        return 'assets/misc/google_drive.png';
      case VaultProvider.iCloud:
        return 'assets/misc/icloud.png';
      case VaultProvider.customLocation:
        return 'assets/misc/custom_location.png';
    }
  }
}
