import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';

/// The descriptor record API, version 1.
///
/// It is additive: wallet backup v1 is frozen and shares nothing with it but
/// the server origin and the field encodings. The domain and the action below
/// are both distinct from every wallet backup value, so neither protocol's
/// signature can ever be replayed as the other's.
const privateDescriptorProtocolVersion = 1;
const privateDescriptorAuthenticationDomain =
    'bullbitcoin-descriptor-backup-v1';
const privateDescriptorStoreAction = 'descriptor-store';

/// A store request carries one to sixteen tokens; the server bounds the rest.
const privateDescriptorMinTokens = 1;
const privateDescriptorMaxTokens = 16;

/// The server's ciphertext bound. The app's own BIP138 limit is half of it, so
/// a record between the two was written by something else and is carried to the
/// codec, which refuses it, rather than discarded here as malformed.
const privateDescriptorMaxCiphertextBytes = 65536;

/// SHA-256 of these bytes is what BIP340 signs for a store request.
///
/// Every field after the domain is preceded by exactly one NUL, fields are the
/// exact ASCII sent on the wire, and there is no trailing NUL. The signature
/// therefore binds the publisher, the exact ciphertext and the complete token
/// set: adding, removing or reordering one token invalidates it.
///
/// Returns null when a field could not be sent as written, so an unsignable
/// request is never sent rather than signed over something else.
Uint8List? buildPrivateDescriptorSigningMessage({
  required String publicKeyHex,
  required String ciphertextSha256,
  required int ciphertextBytes,
  required List<String> lookupTokens,
  required int timestamp,
}) {
  if (!isWalletBackupHash(publicKeyHex) ||
      !isWalletBackupHash(ciphertextSha256) ||
      ciphertextBytes <= 0 ||
      ciphertextBytes > privateDescriptorMaxCiphertextBytes ||
      timestamp < 0 ||
      !isCanonicalPrivateDescriptorTokens(lookupTokens)) {
    return null;
  }
  final bytes = BytesBuilder()
    ..add(utf8.encode(privateDescriptorAuthenticationDomain));
  for (final field in [
    privateDescriptorStoreAction,
    publicKeyHex,
    ciphertextSha256,
    '$ciphertextBytes',
    '${lookupTokens.length}',
    ...lookupTokens,
    '$timestamp',
  ]) {
    bytes
      ..addByte(0)
      ..add(utf8.encode(field));
  }
  return bytes.toBytes();
}

/// Strictly ascending, which makes the set sorted and duplicate free at once.
///
/// The server does not reorder the set for the client, because the signature
/// covers the exact sequence sent.
bool isCanonicalPrivateDescriptorTokens(List<String> tokens) {
  if (tokens.length < privateDescriptorMinTokens ||
      tokens.length > privateDescriptorMaxTokens) {
    return false;
  }
  for (var index = 0; index < tokens.length; index++) {
    if (!isWalletBackupHash(tokens[index]) ||
        (index > 0 && tokens[index].compareTo(tokens[index - 1]) <= 0)) {
      return false;
    }
  }
  return true;
}
