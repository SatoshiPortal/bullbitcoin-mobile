import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart';

class BackupInfo {
  final String backupFile;

  const BackupInfo({required this.backupFile});

  // Domain-specific getters that encapsulate BullBackup usage
  bool get isCorrupted {
    try {
      return !BullBackup.isValid(backupFile);
    } catch (_) {
      return true;
    }
  }

  String get salt => HEX.encode(BullBackup.fromJson(backupFile).salt);
  String? get path => BullBackup.fromJson(backupFile).path;
  String get id => HEX.encode(BullBackup.fromJson(backupFile).id);
  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(
        BullBackup.fromJson(backupFile).createdAt,
      );
}
