import 'dart:typed_data';

import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/wallet_backup_failure_mapper.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

sealed class SelectedWalletBackupFileOutcome {
  const SelectedWalletBackupFileOutcome();
}

final class WalletBackupFileRecovered extends SelectedWalletBackupFileOutcome {
  final WalletBackupRecoveryResult result;

  const WalletBackupFileRecovered(this.result);
}

final class WalletBackupFileReselection
    extends SelectedWalletBackupFileOutcome {
  final Uint8List bytes;
  final WalletBackupImportComparison comparison;

  const WalletBackupFileReselection(this.bytes, this.comparison);
}

final class ImportWalletBackupFileUsecase {
  final WalletBackupFacade _walletBackup;
  final WalletBackupFileRepository _files;

  const ImportWalletBackupFileUsecase(this._walletBackup, this._files);

  @useResult
  Future<
    Result<
      ({Uint8List bytes, WalletBackupImportComparison comparison})?,
      BackupSettingsFailure
    >
  >
  execute() async {
    switch (await _files.pick(
      maximumBytes: WalletBackupExport.maximumFileBytes,
    )) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: null):
        return const Ok(null);
      case Ok(value: final bytes?):
        return _compare(_walletBackup, bytes);
    }
  }
}

final class ResumeWalletBackupFileImportUsecase {
  final WalletBackupFacade _walletBackup;

  const ResumeWalletBackupFileImportUsecase(this._walletBackup);

  @useResult
  Future<
    Result<
      ({Uint8List bytes, WalletBackupImportComparison comparison}),
      BackupSettingsFailure
    >
  >
  execute() async {
    final export = await _walletBackup.buildExport(
      protection: WalletBackupFileProtection.unencrypted,
      confirmedUnencrypted: true,
    );
    final Uint8List bytes;
    switch (export) {
      case Err(:final failure):
        return Err(mapWalletBackupFailure(failure));
      case Ok(:final value):
        bytes = value.copyBytes();
    }
    return _compare(_walletBackup, bytes);
  }
}

final class RecoverSelectedWalletBackupFileUsecase {
  final WalletBackupFacade _walletBackup;

  const RecoverSelectedWalletBackupFileUsecase(this._walletBackup);

  @useResult
  Future<Result<SelectedWalletBackupFileOutcome, BackupSettingsFailure>>
  execute({
    required Uint8List bytes,
    required WalletBackupImportComparison comparison,
    required WalletBackupImportSource source,
  }) async {
    final result = await _walletBackup.recoverComparedFile(
      fileBytes: bytes,
      comparison: comparison,
      source: source,
    );
    if (result.status != WalletBackupRecoveryStatus.comparisonStale) {
      return Ok(WalletBackupFileRecovered(result));
    }
    return switch (await _compare(_walletBackup, bytes)) {
      Ok(:final value) => Ok(
        WalletBackupFileReselection(value.bytes, value.comparison),
      ),
      Err(:final failure) => Err(failure),
    };
  }
}

Future<
  Result<
    ({Uint8List bytes, WalletBackupImportComparison comparison}),
    BackupSettingsFailure
  >
>
_compare(WalletBackupFacade walletBackup, Uint8List bytes) async =>
    switch (await walletBackup.compareFile(bytes)) {
      Ok(:final value) => Ok((bytes: bytes, comparison: value)),
      Err(:final failure) => Err(mapWalletBackupFailure(failure)),
    };
