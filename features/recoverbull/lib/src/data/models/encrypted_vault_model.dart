import 'dart:convert';

import 'package:convert/convert.dart' as convert;
import 'package:recoverbull/recoverbull.dart' as sdk;

import '../../domain/entities/vault_passkey.dart';

/// Wire fields for the published v1 encrypted-backup format.
final class EncryptedVaultModel {
  final int createdAt;
  final List<int> id;
  final List<int> ciphertext;
  final List<int> salt;
  final String? path;
  final VaultPasskey? passkey;

  const EncryptedVaultModel({
    required this.createdAt,
    required this.id,
    required this.ciphertext,
    required this.salt,
    this.path,
    this.passkey,
  });

  factory EncryptedVaultModel.fromFile(String file) {
    final backup = sdk.BullBackup.fromJson(file);
    final decoded = jsonDecode(file) as Map<String, dynamic>;
    VaultPasskey? passkey;
    if (decoded.containsKey('passkey')) {
      final block = decoded['passkey'];
      if (block is! Map<String, dynamic> ||
          block.length != 4 ||
          block['version'] is! int ||
          block['version'] != VaultPasskey.version ||
          block['rp_id'] is! String ||
          block['credential_id'] is! String ||
          block['prf_salt'] is! String) {
        throw const FormatException('Invalid passkey metadata');
      }
      try {
        passkey = VaultPasskey(
          rpId: block['rp_id'] as String,
          credentialId: _decodeBase64Url(block['credential_id'] as String),
          prfSalt: _decodeBase64Url(block['prf_salt'] as String),
        );
      } on ArgumentError {
        throw const FormatException('Invalid passkey metadata');
      }
    }
    if (backup.createdAt.abs() > 8640000000000000) {
      throw const FormatException('Invalid vault timestamp');
    }
    return EncryptedVaultModel(
      createdAt: backup.createdAt,
      id: backup.id,
      ciphertext: backup.ciphertext,
      salt: backup.salt,
      path: backup.path,
      passkey: passkey,
    );
  }

  String toFile() => jsonEncode({
    'version': 1,
    'created_at': createdAt,
    'id': convert.hex.encode(id),
    'ciphertext': base64.encode(ciphertext),
    'salt': convert.hex.encode(salt),
    'path': path,
    if (passkey case final value?)
      'passkey': {
        'version': VaultPasskey.version,
        'rp_id': value.rpId,
        'credential_id': _encodeBase64Url(value.credentialId),
        'prf_salt': _encodeBase64Url(value.prfSalt),
      },
  });

  static String _encodeBase64Url(List<int> value) =>
      base64Url.encode(value).replaceAll('=', '');

  static List<int> _decodeBase64Url(String value) {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
      throw const FormatException('Invalid passkey encoding');
    }
    final decoded = base64Url.decode(base64Url.normalize(value));
    if (_encodeBase64Url(decoded) != value) {
      throw const FormatException('Non-canonical passkey encoding');
    }
    return decoded;
  }
}
