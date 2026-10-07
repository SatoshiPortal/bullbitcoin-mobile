import 'package:convert/convert.dart' as convert;
import 'package:recoverbull/recoverbull.dart' as recoverbull;

class EncryptedVault {
  late recoverbull.BullBackup backup;

  EncryptedVault({required String file}) {
    backup = recoverbull.BullBackup.fromJson(file);
  }

  String toFile() => backup.toJson();

  static bool isValid(String file) => recoverbull.BullBackup.isValid(file);

  String get salt => convert.hex.encode(backup.salt);

  /// The BIP85 path the vault key was derived from, or null for a vault file
  /// that does not record it.
  String? get derivationPath => backup.path;

  String get id => convert.hex.encode(backup.id);

  DateTime get createdAt =>
      DateTime.fromMillisecondsSinceEpoch(backup.createdAt);

  String get filename =>
      '${createdAt.toIso8601String().substring(0, 10)}_encrypted_vault.json';
}
