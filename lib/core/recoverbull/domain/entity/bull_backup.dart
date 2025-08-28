import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;

class BullBackupEntity {
  late recoverbull.BullBackup backup;

  BullBackupEntity({required String backupFile}) {
    backup = recoverbull.BullBackup.fromJson(backupFile);
  }

  String toFile() => backup.toJson();

  static bool isValid(String backupFile) =>
      recoverbull.BullBackup.isValid(backupFile);

  String get salt => HEX.encode(backup.salt);

  String get derivationPath {
    if (backup.path == null) throw BullBackupMissingPath();
    return backup.path!;
  }

  String get id => HEX.encode(backup.id);

  DateTime get createdAt =>
      DateTime.fromMillisecondsSinceEpoch(backup.createdAt);

  String get filename => '${createdAt.toIso8601String()}_$id.json';
}

class BullBackupException implements Exception {
  final String message;

  BullBackupException(this.message);

  @override
  String toString() => message;
}

class BullBackupMissingPath extends BullBackupException {
  BullBackupMissingPath() : super('Bull backup derivationPath is missing path');
}
