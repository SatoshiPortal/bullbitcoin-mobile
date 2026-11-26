import 'dart:io';

import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';

import 'recoverbull_cutover.dart';
import 'wallet_backup_import.dart';

/// Retirement proof for the wallet-backup projection.
///
/// The projection copies the retired wallet columns and records a secondary
/// receipt in each network's own store. The legacy file may go only once both
/// the mainnet and the regtest receipts exist; either one missing refuses.
/// There is no keychain entry to delete.
final class RecoverBullRetirement implements LegacyRetirementParticipant {
  final RecoverBullCutover mainnet;
  final RecoverBullCutover regtest;

  const RecoverBullRetirement({required this.mainnet, required this.regtest});

  @override
  String get ownerId => 'recoverbull';

  @override
  Future<Result<void, LegacyImportFailure>> verifyRetirable(
    ExclusiveAdmission admission, {
    required OwnerOrigin origin,
    required LegacySource source,
  }) async {
    if (mainnet.regtest || !regtest.regtest) {
      return const Err(LegacyImportVerificationFailed());
    }
    try {
      if (await mainnet.file.resolveSymbolicLinks() ==
          await regtest.file.resolveSymbolicLinks()) {
        return const Err(LegacyImportVerificationFailed());
      }
      final mainStat = await mainnet.file.stat();
      final regtestStat = await regtest.file.stat();
      if (mainStat.type != FileSystemEntityType.file ||
          regtestStat.type != FileSystemEntityType.file ||
          await FileSystemEntity.identical(
            mainnet.file.path,
            regtest.file.path,
          )) {
        return const Err(LegacyImportVerificationFailed());
      }
    } on FileSystemException {
      return const Err(LegacyImportUnavailable());
    }
    for (final cutover in [mainnet, regtest]) {
      switch (await hasWalletBackupReceipt(
        cutover: cutover,
        admission: admission,
      )) {
        case Ok(value: true):
          break;
        case Ok():
          return const Err(LegacyImportVerificationFailed());
        case Err(:final failure):
          return Err(failure);
      }
    }
    return const Ok(null);
  }
}
