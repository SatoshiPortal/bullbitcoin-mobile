import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:crypto/crypto.dart';

const bullnymWireDomain = 'bullpay-la-v2';
const bullnymBackupWireDomain = 'bullbitcoin-wallet-backup-v1';
const bullnymBackupEtagDomain = 'bullbitcoin-wallet-backup-etag-v1';

final _hashPattern = RegExp(r'^[0-9a-f]{64}$');
final _signaturePattern = RegExp(r'^[0-9a-f]{128}$');

final class BullnymAuthentication {
  final String npubHex;
  final String signatureHex;
  final int timestamp;

  const BullnymAuthentication({
    required this.npubHex,
    required this.signatureHex,
    required this.timestamp,
  });
}

final class BullnymAuthenticator {
  final NostrIdentityFacade _identity;
  final int Function() _nowSecs;
  final bool _walletBackupIdentity;

  const BullnymAuthenticator(
    this._identity, {
    this._nowSecs = currentBullnymTimestampSecs,
  }) : _walletBackupIdentity = false;

  const BullnymAuthenticator.walletBackup(
    this._identity, {
    this._nowSecs = currentBullnymTimestampSecs,
  }) : _walletBackupIdentity = true;

  Future<Result<String, BullnymFailure>> publicKey() async {
    final result = _walletBackupIdentity
        ? await _identity.walletBackupPublicKey()
        : await _identity.bullnymAuthPublicKey();
    return switch (result) {
      Ok(:final value) => Ok(value.hex),
      Err(:final failure) => Err(
        BullnymAuthenticationFailure(failure.runtimeType.toString()),
      ),
    };
  }

  Future<Result<BullnymAuthentication, BullnymFailure>> sign({
    required String action,
    required String nym,
    required List<String> fields,
  }) async {
    final String npubHex;
    switch (await publicKey()) {
      case Ok(:final value):
        npubHex = value;
      case Err(:final failure):
        return Err(failure);
    }
    final timestamp = _nowSecs();
    final message = buildBullnymMessage(
      action: action,
      npubHex: npubHex,
      nym: nym,
      fields: fields,
      timestamp: timestamp,
    );
    if (message == null) {
      return const Err(BullnymInvalidInputFailure('Invalid signing field'));
    }
    return _sign(npubHex, timestamp, message);
  }

  Future<Result<BullnymAuthentication, BullnymFailure>> signBackup({
    required String action,
    required BullnymBackupStream stream,
    required int generation,
    required String expectedEtag,
    required String ciphertextSha256,
    required int ciphertextBytes,
  }) async {
    final String npubHex;
    switch (await publicKey()) {
      case Ok(:final value):
        npubHex = value;
      case Err(:final failure):
        return Err(failure);
    }
    final timestamp = _nowSecs();
    final message = buildBullnymBackupMessage(
      action: action,
      stream: stream,
      npubHex: npubHex,
      generation: generation,
      expectedEtag: expectedEtag,
      ciphertextSha256: ciphertextSha256,
      ciphertextBytes: ciphertextBytes,
      timestamp: timestamp,
    );
    if (message == null) {
      return const Err(
        BullnymInvalidInputFailure('Invalid backup signing field'),
      );
    }
    return _sign(npubHex, timestamp, message);
  }

  Future<Result<BullnymAuthentication, BullnymFailure>> _sign(
    String npubHex,
    int timestamp,
    Uint8List message,
  ) async {
    final digest = sha256.convert(message).toString();
    final signature = _walletBackupIdentity
        ? await _identity.signWalletBackupHash(digest)
        : await _identity.signBullnymAuthHash(digest);
    switch (signature) {
      case Err(:final failure):
        return Err(
          BullnymAuthenticationFailure(failure.runtimeType.toString()),
        );
      case Ok(:final value):
        if (!_signaturePattern.hasMatch(value)) {
          return const Err(BullnymAuthenticationFailure('Invalid signature'));
        }
        return Ok(
          BullnymAuthentication(
            npubHex: npubHex,
            signatureHex: value,
            timestamp: timestamp,
          ),
        );
    }
  }
}

Uint8List? buildBullnymMessage({
  required String action,
  required String npubHex,
  required String nym,
  required List<String> fields,
  required int timestamp,
}) {
  if (!_hashPattern.hasMatch(npubHex) || timestamp < 0) return null;
  final builder = BytesBuilder();
  for (final field in [bullnymWireDomain, action, npubHex, nym, ...fields]) {
    if (field.contains('\u0000')) return null;
    builder
      ..add(utf8.encode(field))
      ..addByte(0);
  }
  builder.add(utf8.encode(timestamp.toString()));
  return builder.toBytes();
}

Uint8List? buildBullnymBackupMessage({
  required String action,
  required BullnymBackupStream stream,
  required String npubHex,
  required int generation,
  required String expectedEtag,
  required String ciphertextSha256,
  required int ciphertextBytes,
  required int timestamp,
}) {
  if (!const {
        'backup-fetch',
        'backup-store',
        'backup-delete',
      }.contains(action) ||
      !_hashPattern.hasMatch(npubHex) ||
      generation < 0 ||
      ciphertextBytes < 0 ||
      timestamp < 0 ||
      !_optionalHash(expectedEtag) ||
      !_optionalHash(ciphertextSha256)) {
    return null;
  }
  final builder = BytesBuilder();
  for (final field in [
    bullnymBackupWireDomain,
    action,
    stream.wireName,
    npubHex,
    '$generation',
    expectedEtag,
    ciphertextSha256,
    '$ciphertextBytes',
  ]) {
    builder
      ..add(utf8.encode(field))
      ..addByte(0);
  }
  builder.add(utf8.encode('$timestamp'));
  return builder.toBytes();
}

String? computeBullnymBackupEtag({
  required BullnymBackupStream stream,
  required String npubHex,
  required int generation,
  required String ciphertextSha256,
}) {
  if (!_hashPattern.hasMatch(npubHex) ||
      generation <= 0 ||
      !_optionalHash(ciphertextSha256)) {
    return null;
  }
  return sha256
      .convert(
        utf8.encode(
          '$bullnymBackupEtagDomain\u0000${stream.wireName}\u0000$npubHex\u0000'
          '$generation\u0000$ciphertextSha256',
        ),
      )
      .toString();
}

bool _optionalHash(String value) =>
    value.isEmpty || _hashPattern.hasMatch(value);

int currentBullnymTimestampSecs() =>
    DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
