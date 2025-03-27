import 'package:recoverbull/recoverbull.dart';

class RecoverBullDatasource {
  static String create(List<int> secret, List<int> backupKey) {
    final backup = RecoverBull.createBackup(
      secret: secret,
      backupKey: backupKey,
    );
    return backup.toJson();
  }

  static List<int> restore(String jsonBackup, List<int> backupKey) {
    final backup = BullBackup.fromJson(jsonBackup);
    return RecoverBull.restoreBackup(backup: backup, backupKey: backupKey);
  }
}
