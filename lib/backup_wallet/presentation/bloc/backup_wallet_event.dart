part of 'backup_wallet_bloc.dart';

sealed class BackupWalletEvent {
  const BackupWalletEvent();
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
