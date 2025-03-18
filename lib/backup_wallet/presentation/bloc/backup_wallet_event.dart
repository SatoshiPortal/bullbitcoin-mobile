part of 'backup_wallet_bloc.dart';

sealed class BackupWalletEvent {
  const BackupWalletEvent();
}

class OnStoreBackUpKey extends BackupWalletEvent {
  final String secret;
  const OnStoreBackUpKey(this.secret);
}

class OnConfirmBackUpKeySecret extends BackupWalletEvent {
  final String secret;
  const OnConfirmBackUpKeySecret(this.secret);
}

class StartWalletBackup extends BackupWalletEvent {
  const StartWalletBackup();
}

class OnFileSystemBackupSelected extends BackupWalletEvent {
  const OnFileSystemBackupSelected();
}

class OnGoogleDriveBackupSelected extends BackupWalletEvent {
  const OnGoogleDriveBackupSelected();
}

class OnICloudDriveBackupSelected extends BackupWalletEvent {
  const OnICloudDriveBackupSelected();
}
