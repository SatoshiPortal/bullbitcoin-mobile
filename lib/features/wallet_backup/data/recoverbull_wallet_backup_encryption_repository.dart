import 'dart:convert';

import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_backup_envelope_model.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_envelope.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_encryption_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

final class RecoverBullWalletBackupEncryptionRepository
    implements WalletBackupEncryptionRepository {
  final WalletBackupEnvelopeCodec _envelopeCodec;
  final RecoverBullAuthenticatedBackupCipher _cipher;

  const RecoverBullWalletBackupEncryptionRepository({
    this._envelopeCodec = const WalletBackupEnvelopeCodec(),
    this._cipher = const RecoverBullAuthenticatedBackupCipher(),
  });

  @override
  @useResult
  Result<String, WalletBackupFailure> contentHash(
    WalletBackupEnvelope envelope,
  ) {
    try {
      return Ok(
        sha256.convert(utf8.encode(_envelopeCodec.encode(envelope))).toString(),
      );
    } on WalletBackupEnvelopeCodecException catch (error, trace) {
      return Err(_mapCodecFailure(error, trace));
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to hash wallet backup',
        error: error.runtimeType,
        trace: trace,
      );
      return Err(WalletBackupUnexpectedFailure(error.runtimeType.toString()));
    }
  }

  @override
  @useResult
  Result<WalletBackupCiphertext, WalletBackupFailure> encrypt({
    required WalletBackupEnvelope envelope,
    required WalletBackupEncryptionKey key,
  }) {
    try {
      final ciphertext = _cipher.encrypt(
        plaintext: _envelopeCodec.encode(envelope),
        key: AuthenticatedBackupCipherKey(key.hex),
      );
      return Ok(WalletBackupCiphertext(ciphertext.value));
    } on WalletBackupEnvelopeCodecException catch (error, trace) {
      return Err(_mapCodecFailure(error, trace));
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to encrypt wallet backup',
        error: error.runtimeType,
        trace: trace,
      );
      return Err(WalletBackupEncryptionFailure(error.runtimeType.toString()));
    }
  }

  @override
  @useResult
  Result<WalletBackupEnvelope, WalletBackupFailure> decrypt({
    required WalletBackupCiphertext ciphertext,
    required WalletBackupEncryptionKey key,
    required String expectedParentFingerprint,
  }) {
    try {
      final plaintext = _cipher.decrypt(
        ciphertext: AuthenticatedBackupCiphertext(ciphertext.value),
        key: AuthenticatedBackupCipherKey(key.hex),
      );
      return Ok(
        _envelopeCodec.decode(
          plaintext,
          expectedParentFingerprint: expectedParentFingerprint,
        ),
      );
    } on WalletBackupEnvelopeCodecException catch (error, trace) {
      return Err(_mapCodecFailure(error, trace));
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to decrypt wallet backup',
        error: error.runtimeType,
        trace: trace,
      );
      return Err(WalletBackupEncryptionFailure(error.runtimeType.toString()));
    }
  }
}

WalletBackupFailure _mapCodecFailure(
  WalletBackupEnvelopeCodecException error,
  StackTrace trace,
) {
  log.warning(
    'Wallet backup envelope validation failed',
    error: error.reason.name,
    trace: trace,
  );
  return switch (error.reason) {
    WalletBackupEnvelopeCodecFailureReason.unsupportedEnvelopeVersion =>
      WalletBackupUnsupportedEnvelopeVersionFailure(error.version!),
    WalletBackupEnvelopeCodecFailureReason.unsupportedSection =>
      WalletBackupUnsupportedSectionFailure(
        sectionId: error.sectionId!,
        version: error.version,
      ),
    WalletBackupEnvelopeCodecFailureReason.parentFingerprintMismatch =>
      const WalletBackupParentFingerprintMismatchFailure(),
    WalletBackupEnvelopeCodecFailureReason.tooLarge =>
      const WalletBackupTooLargeFailure(),
    WalletBackupEnvelopeCodecFailureReason.malformed ||
    WalletBackupEnvelopeCodecFailureReason.nonCanonical =>
      WalletBackupInvalidEnvelopeFailure(error.reason.name),
  };
}
