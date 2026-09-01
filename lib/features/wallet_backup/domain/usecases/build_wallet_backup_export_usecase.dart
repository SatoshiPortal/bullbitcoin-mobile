import 'dart:convert';

import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_encryption_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/resolve_wallet_backup_key_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:primitives/primitives.dart';

typedef BuildWalletBackupSnapshot =
    Future<Result<WalletBackupSnapshot, WalletBackupFailure>> Function({
      required String parentFingerprint,
      bool allowEmpty,
    });

final class BuildWalletBackupExportUsecase {
  final BuildWalletBackupSnapshot _buildSnapshot;
  final Future<Result<WalletBackupKey, WalletBackupFailure>> Function()
  _resolveKey;
  final WalletBackupEncryptionRepository _encryption;
  final DateTime Function() _nowUtc;

  const BuildWalletBackupExportUsecase({
    required this._buildSnapshot,
    required this._resolveKey,
    required this._encryption,
    this._nowUtc = _systemNowUtc,
  });

  Future<Result<WalletBackupExport, WalletBackupFailure>> execute({
    required WalletBackupFileProtection protection,
    required bool confirmedUnencrypted,
  }) async {
    if (protection == WalletBackupFileProtection.unencrypted &&
        !confirmedUnencrypted) {
      return const Err(WalletBackupConfirmationRequiredFailure());
    }

    final WalletBackupKey key;
    switch (await _resolveKey()) {
      case Ok(:final value):
        key = value;
      case Err(:final failure):
        return Err(failure);
    }
    final snapshotResult = await _buildSnapshot(
      parentFingerprint: key.parentFingerprint,
      allowEmpty: true,
    );
    final WalletBackupSnapshot envelope;
    switch (snapshotResult) {
      case Ok(:final value):
        envelope = value;
      case Err(:final failure):
        return Err(failure);
    }

    final List<int> bytes;
    final String extension;
    switch (protection) {
      case WalletBackupFileProtection.unencrypted:
        switch (_encryption.encodeCanonical(envelope)) {
          case Ok(:final value):
            bytes = value;
          case Err(:final failure):
            return Err(failure);
        }
        extension = 'json';
      case WalletBackupFileProtection.encrypted:
        switch (_encryption.encrypt(
          envelope: envelope,
          key: key.encryptionKey,
        )) {
          case Ok(:final value):
            bytes = utf8.encode(value.value);
          case Err(:final failure):
            return Err(failure);
        }
        extension = 'json.enc';
    }

    return Ok(
      WalletBackupExport(
        suggestedFilename:
            'bull-wallet-data-backup-${_timestamp(_nowUtc())}.$extension',
        bytes: bytes,
      ),
    );
  }
}

String _timestamp(DateTime value) {
  final utc = value.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${utc.year}${two(utc.month)}${two(utc.day)}-'
      '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}';
}

DateTime _systemNowUtc() => DateTime.now().toUtc();
