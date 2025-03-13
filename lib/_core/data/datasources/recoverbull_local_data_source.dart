import 'package:recoverbull/recoverbull.dart';

abstract class RecoverBullLocalDataSource {
  String createBackup(List<int> secret, List<int> backupKey);

  List<int> restoreBackup(String backup, List<int> backupKey);
}

class RecoverBullLocalDataSourceImpl implements RecoverBullLocalDataSource {
  @override
  String createBackup(List<int> secret, List<int> backupKey) {
    final backup = RecoverBull.createBackup(
      secret: secret,
      backupKey: backupKey,
    );
    return backup.toJson();
  }

  @override
  List<int> restoreBackup(String jsonBackup, List<int> backupKey) {
    final backup = BullBackup.fromJson(jsonBackup);
    return RecoverBull.restoreBackup(backup: backup, backupKey: backupKey);
  }
}
