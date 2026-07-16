import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

const walletBackupWireDomain = 'bullbitcoin-wallet-backup-v1';
const walletBackupEtagDomain = 'bullbitcoin-wallet-backup-etag-v1';
const walletBackupFetchAction = 'backup-fetch';
const walletBackupStoreAction = 'backup-store';
const walletBackupDeleteAction = 'backup-delete';

final _canonicalHashPattern = RegExp(r'^[0-9a-f]{64}$');
final _canonicalSignaturePattern = RegExp(r'^[0-9a-f]{128}$');

@useResult
Result<Uint8List, BullnymFailure> buildWalletBackupSchnorrMessage({
  required String action,
  required BullnymBackupStream stream,
  required String npubHex,
  required int generation,
  required String expectedEtag,
  required String ciphertextSha256,
  required int ciphertextBytes,
  required int timestampSecs,
}) {
  switch (validateBullnymNpubHex(npubHex)) {
    case Err(:final failure):
      return Err(failure);
    case Ok():
      break;
  }
  if (action != walletBackupFetchAction &&
      action != walletBackupStoreAction &&
      action != walletBackupDeleteAction) {
    return const Err(BullnymFailure.invalidInput('Unknown backup action'));
  }
  if (generation < 0 || ciphertextBytes < 0 || timestampSecs < 0) {
    return const Err(
      BullnymFailure.invalidInput('Backup numeric fields must be non-negative'),
    );
  }
  if (!_isOptionalHash(expectedEtag) || !_isOptionalHash(ciphertextSha256)) {
    return const Err(
      BullnymFailure.invalidInput(
        'Backup hashes must be empty or canonical lowercase hex',
      ),
    );
  }

  final builder = BytesBuilder();
  for (final field in [
    walletBackupWireDomain,
    action,
    stream.wireName,
    npubHex,
    generation.toString(),
    expectedEtag,
    ciphertextSha256,
    ciphertextBytes.toString(),
  ]) {
    if (field.contains('\u0000')) {
      return const Err(
        BullnymFailure.invalidInput(
          'Backup signing fields must not contain null separators',
        ),
      );
    }
    builder
      ..add(utf8.encode(field))
      ..addByte(0);
  }
  builder.add(utf8.encode(timestampSecs.toString()));
  return Ok(builder.toBytes());
}

@useResult
Result<String, BullnymFailure> computeWalletBackupEtag({
  required BullnymBackupStream stream,
  required String npubHex,
  required int generation,
  required String ciphertextSha256,
}) {
  switch (validateBullnymNpubHex(npubHex)) {
    case Err(:final failure):
      return Err(failure);
    case Ok():
      break;
  }
  if (generation <= 0 || !_isOptionalHash(ciphertextSha256)) {
    return const Err(
      BullnymFailure.invalidInput('Backup ETag fields are invalid'),
    );
  }
  final message = utf8.encode(
    '$walletBackupEtagDomain\u0000${stream.wireName}\u0000$npubHex\u0000'
    '$generation\u0000$ciphertextSha256',
  );
  return Ok(sha256.convert(message).toString());
}

@useResult
Future<Result<String, BullnymFailure>> signWalletBackupAction({
  required BullnymAuthSigner signer,
  required String action,
  required BullnymBackupStream stream,
  required int generation,
  required String expectedEtag,
  required String ciphertextSha256,
  required int ciphertextBytes,
  required int timestampSecs,
}) async {
  final messageResult = buildWalletBackupSchnorrMessage(
    action: action,
    stream: stream,
    npubHex: signer.npubHex,
    generation: generation,
    expectedEtag: expectedEtag,
    ciphertextSha256: ciphertextSha256,
    ciphertextBytes: ciphertextBytes,
    timestampSecs: timestampSecs,
  );
  final Uint8List message;
  switch (messageResult) {
    case Err(:final failure):
      return Err(failure);
    case Ok(:final value):
      message = value;
  }
  try {
    final signature = await Future<String>.value(
      signer.signHashHex(hex.encode(sha256.convert(message).bytes)),
    );
    if (!_canonicalSignaturePattern.hasMatch(signature)) {
      return const Err(BullnymFailure.signingFailed());
    }
    return Ok(signature);
  } on Exception {
    return const Err(BullnymFailure.signingFailed());
  }
}

bool _isOptionalHash(String value) {
  return value.isEmpty || _canonicalHashPattern.hasMatch(value);
}
