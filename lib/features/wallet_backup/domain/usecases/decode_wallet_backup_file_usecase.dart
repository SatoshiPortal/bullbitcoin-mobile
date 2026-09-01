import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_encryption_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/resolve_wallet_backup_key_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_file_signature.dart';
import 'package:primitives/primitives.dart';

final class DecodeWalletBackupFileUsecase {
  static const maximumFileBytes = WalletBackupCiphertext.maximumEncodedLength;

  final Future<Result<WalletBackupKey, WalletBackupFailure>> Function()
  _resolveKey;
  final WalletBackupEncryptionRepository _encryption;
  final NostrIdentityFacade _identity;

  const DecodeWalletBackupFileUsecase(
    this._resolveKey,
    this._encryption,
    this._identity,
  );

  Future<Result<WalletBackupSnapshot, WalletBackupFailure>> execute(
    Uint8List bytes,
  ) async {
    if (bytes.isEmpty) {
      return const Err(WalletBackupInvalidEnvelopeFailure());
    }
    if (bytes.length > maximumFileBytes) {
      return const Err(WalletBackupTooLargeFailure());
    }
    final WalletBackupKey key;
    switch (await _resolveKey()) {
      case Ok(:final value):
        key = value;
      case Err(:final failure):
        return Err(failure);
    }
    final String text;
    try {
      text = const Utf8Decoder(allowMalformed: false).convert(bytes);
    } on FormatException {
      return const Err(WalletBackupInvalidEnvelopeFailure());
    }
    if (text.trimLeft().startsWith('{')) {
      return _decodeReadable(text, key.parentFingerprint);
    }
    final ciphertext = WalletBackupCiphertext.tryParse(text);
    if (ciphertext == null) {
      return const Err(WalletBackupInvalidEnvelopeFailure());
    }
    return _encryption.decrypt(
      ciphertext: ciphertext,
      key: key.encryptionKey,
      expectedParentFingerprint: key.parentFingerprint,
    );
  }

  Future<Result<WalletBackupSnapshot, WalletBackupFailure>> _decodeReadable(
    String text,
    String expectedParentFingerprint,
  ) async {
    final Map<String, dynamic> root;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        return const Err(WalletBackupInvalidEnvelopeFailure());
      }
      root = decoded;
    } on FormatException {
      return const Err(WalletBackupInvalidEnvelopeFailure());
    }
    final signature = root.remove('signature');
    if (signature is! String ||
        !WalletBackupFileSignature.isValidSignature(signature)) {
      return const Err(WalletBackupInvalidEnvelopeFailure());
    }
    final unsignedBytes = Uint8List.fromList(utf8.encode(jsonEncode(root)));
    final WalletBackupSnapshot snapshot;
    switch (_encryption.decodeCanonical(
      bytes: unsignedBytes,
      expectedParentFingerprint: expectedParentFingerprint,
    )) {
      case Ok(:final value):
        snapshot = value;
      case Err(failure: WalletBackupParentFingerprintMismatchFailure()):
        return const Err(WalletBackupInvalidEnvelopeFailure());
      case Err(:final failure):
        return Err(failure);
    }
    final Uint8List canonicalBytes;
    switch (_encryption.encodeCanonical(snapshot)) {
      case Ok(:final value):
        canonicalBytes = value;
      case Err(:final failure):
        return Err(failure);
    }
    final String publicKey;
    switch (await _identity.walletBackupPublicKey()) {
      case Ok(:final value):
        publicKey = value;
      case Err():
        return const Err(WalletBackupSigningFailure());
    }
    if (!WalletBackupFileSignature.verify(
      canonicalUnsignedJson: canonicalBytes,
      publicKeyHex: publicKey,
      signatureHex: signature,
    )) {
      return const Err(WalletBackupInvalidEnvelopeFailure());
    }
    return Ok(snapshot);
  }
}
