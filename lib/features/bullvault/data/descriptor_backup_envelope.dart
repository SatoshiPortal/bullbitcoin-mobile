import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/features/bullvault/data/bip138_codec.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup_key.dart';
import 'package:convert/convert.dart';

/// Experimental outer profile. Hides the entire BIP138 header per recipient.
final class DescriptorBackupEnvelope {
  static const profile = 'bullvault-bip138-prototype-1';
  final Bip138Codec _codec;
  DescriptorBackupEnvelope(this._codec);

  String lookup(DescriptorBackupKey key) =>
      hex.encode(Bip138Codec.taggedHash('$profile/lookup', key.canonicalBytes));

  Uint8List _key(DescriptorBackupKey key) =>
      Bip138Codec.taggedHash('$profile/encryption', key.canonicalBytes);

  List<int> _aad(DescriptorBackupKey key) =>
      utf8.encode('$profile:${lookup(key)}');

  String seal(Uint8List backup, DescriptorBackupKey key) {
    final length = backup.length;
    if (length > Bip138Codec.maxBytes - 4) {
      throw const FormatException('Backup size');
    }
    final paddedLength = ((length + 4 + 4095) ~/ 4096) * 4096;
    final plaintext = Uint8List(paddedLength);
    ByteData.sublistView(plaintext).setUint32(0, length);
    plaintext.setRange(4, length + 4, backup);
    final nonce = _codec.randomNonce();
    return '$profile:${base64Encode([...nonce, ...Bip138Codec.crypt(true, _key(key), nonce, plaintext, _aad(key))])}';
  }

  Uint8List open(String content, DescriptorBackupKey key) {
    if (!content.startsWith('$profile:') || content.length > 45000) {
      throw const FormatException('Unsupported envelope');
    }
    final bytes = base64Decode(content.substring(profile.length + 1));
    if (bytes.length < 32 ||
        bytes.length > Bip138Codec.maxBytes + 28 ||
        bytes.take(12).every((b) => b == 0)) {
      throw const FormatException('Invalid envelope');
    }
    final plaintext = Bip138Codec.crypt(
      false,
      _key(key),
      bytes.sublist(0, 12),
      bytes.sublist(12),
      _aad(key),
    );
    if (plaintext.length < 4) throw const FormatException('Invalid envelope');
    final length = ByteData.sublistView(plaintext).getUint32(0);
    if (length == 0 || length > plaintext.length - 4) {
      throw const FormatException('Invalid envelope length');
    }
    return Uint8List.fromList(plaintext.sublist(4, length + 4));
  }
}
