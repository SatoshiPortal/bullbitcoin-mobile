import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_encryption_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/resolve_wallet_backup_key_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:primitives/primitives.dart';

final class DecodeWalletBackupFileUsecase {
  static const maximumFileBytes = WalletBackupCiphertext.maximumEncodedLength;

  final Future<Result<WalletBackupKey, WalletBackupFailure>> Function()
  _resolveKey;
  final WalletBackupEncryptionRepository _encryption;

  const DecodeWalletBackupFileUsecase(this._resolveKey, this._encryption);

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
      return _encryption.decodeCanonical(
        bytes: bytes,
        expectedParentFingerprint: key.parentFingerprint,
      );
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
}
