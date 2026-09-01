import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:crypto/crypto.dart';

const walletBackupProtocolVersion = 1;
const walletBackupStream = 'wallet_backup';
const walletBackupAuthenticationDomain = 'bullbitcoin-wallet-backup-v1';
const walletBackupEtagDomain = 'bullbitcoin-wallet-backup-etag-v1';

enum WalletBackupAction {
  fetch('backup-fetch'),
  store('backup-store'),
  delete('backup-delete');

  final String wireName;

  const WalletBackupAction(this.wireName);
}

final class WalletBackupAuthentication {
  final String publicKeyHex;
  final String signatureHex;
  final int timestamp;

  WalletBackupAuthentication({
    required this.publicKeyHex,
    required this.signatureHex,
    required this.timestamp,
  }) {
    if (!isWalletBackupHash(publicKeyHex) ||
        !_signaturePattern.hasMatch(signatureHex) ||
        timestamp < 0) {
      throw ArgumentError('Invalid backup authentication');
    }
  }
}

final class WalletBackupAuthenticator {
  final NostrIdentityFacade _identity;
  final int Function() _nowSecs;

  const WalletBackupAuthenticator(
    this._identity, [
    this._nowSecs = currentWalletBackupTimestampSecs,
  ]);

  Future<Result<WalletBackupAuthentication, WalletBackupFailure>> sign({
    required WalletBackupAction action,
    required int generation,
    required String expectedEtag,
    required String ciphertextSha256,
    required int ciphertextBytes,
  }) async {
    final publicKeyResult = await _identity.walletBackupPublicKey();
    final String publicKey;
    switch (publicKeyResult) {
      case Err():
        return const Err(WalletBackupSigningFailure());
      case Ok(:final value):
        publicKey = value;
    }
    final timestamp = _nowSecs();
    final message = buildWalletBackupSigningMessage(
      action: action,
      publicKeyHex: publicKey,
      generation: generation,
      expectedEtag: expectedEtag,
      ciphertextSha256: ciphertextSha256,
      ciphertextBytes: ciphertextBytes,
      timestamp: timestamp,
    );
    if (message == null) {
      return const Err(WalletBackupSigningFailure());
    }
    final digest = sha256.convert(message).toString();
    return switch (await _identity.signWalletBackupHash(digest)) {
      Err() => const Err(WalletBackupSigningFailure()),
      Ok(:final value) when _signaturePattern.hasMatch(value) => Ok(
        WalletBackupAuthentication(
          publicKeyHex: publicKey,
          signatureHex: value,
          timestamp: timestamp,
        ),
      ),
      Ok() => const Err(WalletBackupSigningFailure()),
    };
  }
}

Uint8List? buildWalletBackupSigningMessage({
  required WalletBackupAction action,
  required String publicKeyHex,
  required int generation,
  required String expectedEtag,
  required String ciphertextSha256,
  required int ciphertextBytes,
  required int timestamp,
}) {
  if (!isWalletBackupHash(publicKeyHex) ||
      generation < 0 ||
      generation > _maximumInteger ||
      ciphertextBytes < 0 ||
      ciphertextBytes > _maximumInteger ||
      timestamp < 0 ||
      timestamp > _maximumInteger ||
      !_optionalHash(expectedEtag) ||
      !_optionalHash(ciphertextSha256)) {
    return null;
  }
  final fields = [
    action.wireName,
    walletBackupStream,
    publicKeyHex,
    '$generation',
    expectedEtag,
    ciphertextSha256,
    '$ciphertextBytes',
    '$timestamp',
  ];
  final bytes = BytesBuilder()
    ..add(utf8.encode(walletBackupAuthenticationDomain));
  for (final field in fields) {
    if (field.contains('\u0000')) return null;
    bytes
      ..addByte(0)
      ..add(utf8.encode(field));
  }
  return bytes.toBytes();
}

String? computeWalletBackupEtag({
  required String publicKeyHex,
  required int generation,
  required String ciphertextSha256,
}) {
  if (!isWalletBackupHash(publicKeyHex) ||
      generation <= 0 ||
      generation > _maximumInteger ||
      !_optionalHash(ciphertextSha256)) {
    return null;
  }
  return sha256
      .convert(
        utf8.encode(
          '$walletBackupEtagDomain\u0000$walletBackupStream\u0000'
          '$publicKeyHex\u0000$generation\u0000$ciphertextSha256',
        ),
      )
      .toString();
}

bool _optionalHash(String value) => value.isEmpty || isWalletBackupHash(value);

final _signaturePattern = RegExp(r'^[0-9a-f]{128}$');
const _maximumInteger = 0x7fffffffffffffff;

int currentWalletBackupTimestampSecs() =>
    DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
