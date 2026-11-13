import 'dart:convert';
import 'package:convert/convert.dart' as convert;
import 'package:recoverbull/recoverbull.dart' as sdk;

/// Wire fields for the published v1 encrypted-backup format.
final class EncryptedVaultModel {
  final int createdAt;
  final List<int> id;
  final List<int> ciphertext;
  final List<int> salt;
  final String? path;

  const EncryptedVaultModel({
    required this.createdAt,
    required this.id,
    required this.ciphertext,
    required this.salt,
    this.path,
  });

  factory EncryptedVaultModel.fromFile(String file) {
    final backup = sdk.BullBackup.fromJson(file);
    if (backup.createdAt.abs() > 8640000000000000) {
      throw const FormatException('Invalid vault timestamp');
    }
    return EncryptedVaultModel(
      createdAt: backup.createdAt,
      id: backup.id,
      ciphertext: backup.ciphertext,
      salt: backup.salt,
      path: backup.path,
    );
  }

  String toFile() => jsonEncode({
    'version': 1,
    'created_at': createdAt,
    'id': convert.hex.encode(id),
    'ciphertext': base64.encode(ciphertext),
    'salt': convert.hex.encode(salt),
    'path': path,
  });
}
