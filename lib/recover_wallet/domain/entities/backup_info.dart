import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart';

class BackupInfo {
  final String encrypted;

  const BackupInfo({required this.encrypted});

  // Domain-specific getters that encapsulate BullBackup usage
  bool get isCorrupted {
    try {
      return !BullBackup.isValid(encrypted);
    } catch (_) {
      return true;
    }
  }

  String get salt => HEX.encode(BullBackup.fromJson(encrypted).salt);
  String? get path => BullBackup.fromJson(encrypted).path;
  String get id => HEX.encode(BullBackup.fromJson(encrypted).id);
  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(
        BullBackup.fromJson(encrypted).createdAt,
      );
}
