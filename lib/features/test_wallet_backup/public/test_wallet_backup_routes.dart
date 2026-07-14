enum TestPhysicalBackupFlow { backup, verify }

enum TestWalletBackupRoute {
  testPhysicalBackupFlow('/test-physical-backup-flow');

  final String path;

  const TestWalletBackupRoute(this.path);
}
