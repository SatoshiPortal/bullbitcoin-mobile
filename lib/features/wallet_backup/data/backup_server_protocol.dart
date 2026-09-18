import 'dart:convert';
import 'package:crypto/crypto.dart';

abstract final class BackupServerProtocol {
  static const version = 1;
  static const stream = 'wallet_backup';
  static const maximumBodyBytes = 1572864;
  static const smallBodyBytes = 8192;
  static const maximumGeneration = 0x7fffffffffffffff;

  static String authHash({
    required String action,
    required String identity,
    required int generation,
    required String? expectedEtag,
    required String? ciphertextHash,
    required int ciphertextBytes,
    required int timestamp,
  }) => _hash([
    'bullbitcoin-wallet-backup-v1',
    action,
    stream,
    identity,
    '$generation',
    expectedEtag ?? '',
    ciphertextHash ?? '',
    '$ciphertextBytes',
    '$timestamp',
  ]);

  static String etag({
    required String identity,
    required int generation,
    required String? ciphertextHash,
  }) => _hash([
    'bullbitcoin-wallet-backup-etag-v1',
    stream,
    identity,
    '$generation',
    ciphertextHash ?? '',
  ]);

  static String _hash(List<String> fields) =>
      sha256.convert(utf8.encode(fields.join('\u0000'))).toString();
}
