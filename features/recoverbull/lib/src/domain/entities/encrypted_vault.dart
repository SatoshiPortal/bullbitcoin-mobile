import 'package:convert/convert.dart' as convert;
import 'package:recoverbull/recoverbull.dart' as recoverbull;

/// An encrypted vault file, parsed and validated once at construction.
class EncryptedVault {
  final recoverbull.BullBackup _backup;

  /// Throws when [file] is not a valid vault file.
  EncryptedVault({required String file})
    : _backup = recoverbull.BullBackup.fromJson(file);

  String toFile() => _backup.toJson();

  static bool isValid(String file) => recoverbull.BullBackup.isValid(file);

  String get salt => convert.hex.encode(_backup.salt);

  /// The BIP85 path the vault key was derived from, or null for a vault file
  /// that does not record it.
  String? get derivationPath => _backup.path;

  String get id => convert.hex.encode(_backup.id);

  DateTime get createdAt =>
      DateTime.fromMillisecondsSinceEpoch(_backup.createdAt);

  String get filename =>
      '${createdAt.toIso8601String().substring(0, 10)}_encrypted_vault.json';
}
