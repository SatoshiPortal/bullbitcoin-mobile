import 'dart:convert';
import 'dart:typed_data';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_backup_snapshot_model.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_encryption_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';
import 'package:convert/convert.dart';
import 'package:primitives/primitives.dart' show Fingerprint;
import 'package:recoverbull/recoverbull.dart';

final class RecoverBullWalletBackupEncryptionRepository
    implements WalletBackupEncryptionRepository {
  final WalletBackupSnapshotCodec _codec;

  const RecoverBullWalletBackupEncryptionRepository(this._codec);

  @override
  Result<Uint8List, WalletBackupFailure> encodeCanonical(
    WalletBackupSnapshot envelope,
  ) {
    try {
      return Ok(Uint8List.fromList(utf8.encode(_codec.encode(envelope))));
    } on WalletBackupSnapshotCodecException catch (error, trace) {
      return Err(_mapCodecFailure(error, trace));
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to encode wallet backup',
        error: error.runtimeType,
        trace: trace,
      );
      return Err(WalletBackupUnexpectedFailure(error.runtimeType.toString()));
    }
  }

  @override
  Result<WalletBackupSnapshot, WalletBackupFailure> decodeCanonical({
    required Uint8List bytes,
    required String expectedParentFingerprint,
  }) => _decode(
    () => const Utf8Decoder(allowMalformed: false).convert(bytes),
    expectedParentFingerprint,
    'decode',
  );

  @override
  @useResult
  Result<WalletBackupCiphertext, WalletBackupFailure> encrypt({
    required WalletBackupSnapshot envelope,
    required WalletBackupEncryptionKey key,
  }) {
    try {
      final backup = RecoverBull.createBackup(
        secret: utf8.encode(_codec.encode(envelope)),
        backupKey: hex.decode(key.hex),
      );
      return Ok(WalletBackupCiphertext(base64.encode(backup.ciphertext)));
    } on WalletBackupSnapshotCodecException catch (error, trace) {
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
  Result<WalletBackupSnapshot, WalletBackupFailure> decrypt({
    required WalletBackupCiphertext ciphertext,
    required WalletBackupEncryptionKey key,
    required String expectedParentFingerprint,
  }) => _decode(
    () => utf8.decode(
      RecoverBull.restoreBackup(
        backup: BullBackup(
          createdAt: 0,
          id: const [],
          ciphertext: base64.decode(ciphertext.value),
          salt: const [],
        ),
        backupKey: hex.decode(key.hex),
      ),
    ),
    expectedParentFingerprint,
    'decrypt',
  );

  Result<WalletBackupSnapshot, WalletBackupFailure> _decode(
    String Function() plaintext,
    String expectedParentFingerprint,
    String operation,
  ) {
    final fingerprint = Fingerprint.tryParse(expectedParentFingerprint);
    if (fingerprint == null) {
      return const Err(WalletBackupParentFingerprintMismatchFailure());
    }
    try {
      return Ok(
        _codec.decode(plaintext(), expectedParentFingerprint: fingerprint),
      );
    } on WalletBackupSnapshotCodecException catch (error, trace) {
      return Err(_mapCodecFailure(error, trace));
    } on FormatException catch (error, trace) {
      log.warning(
        'Wallet backup file is not UTF-8',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(WalletBackupInvalidEnvelopeFailure());
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to $operation wallet backup',
        error: error.runtimeType,
        trace: trace,
      );
      return Err(
        operation == 'decrypt'
            ? WalletBackupEncryptionFailure(error.runtimeType.toString())
            : WalletBackupUnexpectedFailure(error.runtimeType.toString()),
      );
    }
  }
}

WalletBackupFailure _mapCodecFailure(
  WalletBackupSnapshotCodecException error,
  StackTrace trace,
) {
  log.warning(
    'Wallet backup envelope validation failed',
    error: error.reason.name,
    trace: trace,
  );
  return switch (error.reason) {
    WalletBackupSnapshotCodecFailureReason.unsupportedVersion =>
      WalletBackupUnsupportedEnvelopeVersionFailure(error.version!),
    WalletBackupSnapshotCodecFailureReason.parentFingerprintMismatch =>
      const WalletBackupParentFingerprintMismatchFailure(),
    WalletBackupSnapshotCodecFailureReason.tooLarge =>
      const WalletBackupTooLargeFailure(),
    WalletBackupSnapshotCodecFailureReason.manifestRejected =>
      WalletBackupManifestFailure(error.detail),
    WalletBackupSnapshotCodecFailureReason.malformed =>
      WalletBackupInvalidEnvelopeFailure(error.reason.name),
  };
}
