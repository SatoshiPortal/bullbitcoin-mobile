import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_recovery_status_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_backup_status.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:meta/meta.dart';

class LoadVaultBackupUsecase {
  final BullVaultFacade _vaults;
  final WalletBackupFacade _backups;
  final GetWalletRecoveryStatusUsecase _wallet;

  const LoadVaultBackupUsecase(this._vaults, this._backups, this._wallet);

  @useResult
  Future<Result<VaultBackupStatus, BackupSettingsFailure>> execute(
    String walletId,
  ) async {
    final BullVaultRecord record;
    switch (await _vaults.getRecord(walletId)) {
      case Ok(value: final value?):
        record = value;
      case _:
        return const Err(BackupSettingsUnexpectedFailure());
    }
    final WalletBackupControl control;
    switch (await _backups.getControl()) {
      case Ok(:final value):
        control = value;
      case Err(:final failure):
        return Err(BackupSettingsFailure.fromDataBackup(failure));
    }
    var canReveal = false;
    if (record.mobileSeedFingerprint case final origin?) {
      switch (await _wallet.execute()) {
        case Ok(:final value):
          canReveal =
              value.masterFingerprint.toLowerCase() == origin.toLowerCase();
        case Err():
          break;
      }
    }
    return Ok(
      VaultBackupStatus(
        record: record,
        control: control,
        canRevealWords: canReveal,
        recoveryPackageSource: _vaults.encodeRecoveryPackage(
          record.recoveryPackage,
        ),
      ),
    );
  }
}

class CheckVaultServerBackupUsecase {
  final BullVaultFacade _vaults;
  final WalletBackupFacade _backups;

  const CheckVaultServerBackupUsecase(this._vaults, this._backups);

  @useResult
  Future<Result<VaultBackupCheck, BackupSettingsFailure>> execute(
    BullVaultRecord expected,
  ) async {
    final WalletBackupInspection inspection;
    switch (await _backups.inspect()) {
      case Ok(:final value):
        inspection = value;
      case Err(:final failure):
        return Err(BackupSettingsFailure.fromDataBackup(failure));
    }
    final entries = inspection.snapshot?.vaults;
    if (entries == null) return const Err(BackupSettingsDataMissingFailure());
    final candidates = entries.where(
      (entry) =>
          entry.recoveryPackage.policy.network ==
              expected.recoveryPackage.policy.network &&
          entry.recoveryPackage.policy.lineageId == expected.lineageId &&
          entry.recoveryPackage.policy.vaultGeneration ==
              expected.vaultGeneration,
    );
    if (candidates.length != 1) {
      return const Err(BackupSettingsVaultMismatchFailure());
    }
    var remote = candidates.single;
    var local = expected;
    final visited = <String>{};
    while (true) {
      if (!visited.add(local.walletId) ||
          remote.status != local.status ||
          (remote.recoveryPackage.previousVaultId == null) !=
              (local.previousVaultId == null)) {
        return const Err(BackupSettingsVaultMismatchFailure());
      }
      // Inventory references are portable; local IDs are not. The predecessor
      // itself is checked below before accepting this translated link.
      final translated = BullVaultRecoveryPackage(
        policy: remote.recoveryPackage.policy,
        previousVaultId: local.previousVaultId,
      );
      final canonicalLocal = _vaults.decodeRecoveryPackage(
        _vaults.encodeRecoveryPackage(local.recoveryPackage),
      );
      switch (canonicalLocal) {
        case Ok(:final value):
          if (local.vaultGeneration != translated.policy.vaultGeneration ||
              local.lineageId != translated.policy.lineageId ||
              !value.canBeEnrichedBy(translated) ||
              !translated.canBeEnrichedBy(value)) {
            return const Err(BackupSettingsVaultMismatchFailure());
          }
        case Err():
          return const Err(BackupSettingsVaultMismatchFailure());
      }
      final previous = local.previousVaultId;
      if (previous == null) break;
      final predecessors = entries.where(
        (entry) => entry.reference == remote.recoveryPackage.previousVaultId,
      );
      if (predecessors.length != 1) {
        return const Err(BackupSettingsVaultMismatchFailure());
      }
      remote = predecessors.single;
      switch (await _vaults.getRecord(previous)) {
        case Ok(value: final value?):
          local = value;
        case _:
          return const Err(BackupSettingsVaultMismatchFailure());
      }
    }
    return switch (await _vaults.verifyBackup(
      expected: expected,
      source: candidates.single.recoveryPackage.policy.descriptor,
      kind: BullVaultBackupTestKind.server,
    )) {
      Ok(:final value) => Ok(
        VaultBackupCheck(expected.copyWith(serverTestedAt: value), inspection),
      ),
      Err(failure: BullVaultBackupMismatchFailure()) => const Err(
        BackupSettingsVaultMismatchFailure(),
      ),
      Err() => const Err(BackupSettingsUnexpectedFailure()),
    };
  }
}

class VerifyVaultDescriptorBackupUsecase {
  final BullVaultFacade _vaults;
  const VerifyVaultDescriptorBackupUsecase(this._vaults);

  @useResult
  Future<Result<DateTime?, BackupSettingsFailure>> execute(
    BullVaultRecord expected, {
    String? source,
  }) async {
    if (source == null) {
      switch (await _vaults.pickRecoveryFile()) {
        case Ok(value: null):
          return const Ok(null);
        case Ok(:final value):
          source = value;
        case Err():
          return const Err(BackupSettingsUnexpectedFailure());
      }
    }
    return switch (await _vaults.verifyBackup(
      expected: expected,
      source: source!,
    )) {
      Ok(:final value) => Ok(value),
      Err(failure: BullVaultBackupMismatchFailure()) => const Err(
        BackupSettingsVaultMismatchFailure(),
      ),
      Err() => const Err(BackupSettingsUnexpectedFailure()),
    };
  }
}
