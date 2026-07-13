import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

const walletBackupWireDomain = 'bullbitcoin-wallet-backup-v1';
const walletBackupEtagDomain = 'bullbitcoin-wallet-backup-etag-v1';
const walletBackupFetchAction = 'backup-fetch';
const walletBackupStoreAction = 'backup-store';
const walletBackupDeleteAction = 'backup-delete';

final _canonicalHashPattern = RegExp(r'^[0-9a-f]{64}$');
final _canonicalSignaturePattern = RegExp(r'^[0-9a-f]{128}$');

Uint8List buildWalletBackupSchnorrMessage({
  required String action,
  required BullnymBackupStream stream,
  required String npubHex,
  required int generation,
  required String expectedEtag,
  required String ciphertextSha256,
  required int ciphertextBytes,
  required int timestampSecs,
}) {
  _validateBackupNpubHex(npubHex);
  if (action != walletBackupFetchAction &&
      action != walletBackupStoreAction &&
      action != walletBackupDeleteAction) {
    throw const BullnymException.invalidInput('Unknown backup signing action');
  }
  if (generation < 0 || ciphertextBytes < 0 || timestampSecs < 0) {
    throw const BullnymException.invalidInput(
      'Backup signing numeric fields must be non-negative',
    );
  }
  _validateOptionalHash(expectedEtag, 'Backup ETag');
  _validateOptionalHash(ciphertextSha256, 'Backup ciphertext hash');
  final fields = [
    walletBackupWireDomain,
    action,
    stream.wireName,
    npubHex,
    generation.toString(),
    expectedEtag,
    ciphertextSha256,
    ciphertextBytes.toString(),
  ];
  final builder = BytesBuilder();
  for (final field in fields) {
    if (field.contains('\u0000')) {
      throw const BullnymException.invalidInput(
        'Backup signing fields must not contain null separators',
      );
    }
    builder
      ..add(utf8.encode(field))
      ..addByte(0);
  }
  builder.add(utf8.encode(timestampSecs.toString()));
  return builder.toBytes();
}

String computeWalletBackupEtag({
  required BullnymBackupStream stream,
  required String npubHex,
  required int generation,
  required String ciphertextSha256,
}) {
  _validateBackupNpubHex(npubHex);
  if (generation <= 0) {
    throw const BullnymException.invalidInput(
      'Backup ETag generation must be positive',
    );
  }
  _validateOptionalHash(ciphertextSha256, 'Backup ciphertext hash');
  final message = utf8.encode(
    '$walletBackupEtagDomain\u0000${stream.wireName}\u0000$npubHex\u0000'
    '$generation\u0000$ciphertextSha256',
  );
  return sha256.convert(message).toString();
}

Future<String> signWalletBackupAction({
  required BullnymAuthSigner signer,
  required String action,
  required BullnymBackupStream stream,
  required int generation,
  required String expectedEtag,
  required String ciphertextSha256,
  required int ciphertextBytes,
  required int timestampSecs,
}) async {
  try {
    final message = buildWalletBackupSchnorrMessage(
      action: action,
      stream: stream,
      npubHex: signer.npubHex,
      generation: generation,
      expectedEtag: expectedEtag,
      ciphertextSha256: ciphertextSha256,
      ciphertextBytes: ciphertextBytes,
      timestampSecs: timestampSecs,
    );
    final signature = await Future<String>.value(
      signer.signHashHex(hex.encode(sha256.convert(message).bytes)),
    );
    if (!_canonicalSignaturePattern.hasMatch(signature)) {
      throw const BullnymException.signingFailed();
    }
    return signature;
  } on BullnymException {
    rethrow;
  } catch (_) {
    throw const BullnymException.signingFailed();
  }
}

void _validateOptionalHash(String value, String description) {
  if (value.isNotEmpty && !_canonicalHashPattern.hasMatch(value)) {
    throw BullnymException.invalidInput(
      '$description must be empty or 32-byte lowercase hex',
    );
  }
}

void _validateBackupNpubHex(String npubHex) {
  switch (validateBullnymNpubHex(npubHex)) {
    case Ok():
      return;
    case Err():
      throw const BullnymException.invalidInput(
        'Backup identity must be 32-byte lowercase hex',
      );
  }
}
