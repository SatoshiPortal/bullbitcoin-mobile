import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_signer_mapper.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_signer_device_port.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/bullvault_backup_entry.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/bullvault_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';

final class BullVaultBackupRepositoryImpl implements BullVaultBackupRepository {
  final SqliteDatabase _database;
  final BullVaultFacade _vaults;
  final WalletMetadataDatasource _wallets;
  final WalletSignerDevicePort _signerDevices;

  const BullVaultBackupRepositoryImpl({
    required this._database,
    required this._vaults,
    required this._wallets,
    required this._signerDevices,
  });

  @override
  Stream<void> get changes => _vaults.watchRecords();

  @override
  Future<Result<List<BullVaultBackupEntry>, WalletBackupFailure>> capture(
    Map<String, String> references,
  ) async {
    try {
      switch (await _vaults.listRecords()) {
        case Err():
          return const Err(WalletBackupIncompleteFailure());
        case Ok(:final value):
          final entries = <BullVaultBackupEntry>[];
          for (final record in value) {
            final reference = references[record.walletId];
            final previous = record.recoveryPackage.previousVaultId;
            if (reference == null ||
                previous != null && !references.containsKey(previous)) {
              return const Err(WalletBackupIncompleteFailure());
            }
            entries.add(
              BullVaultBackupEntry(
                reference: reference,
                status: record.status,
                recoveryPackage: BullVaultRecoveryPackage(
                  policy: record.recoveryPackage.policy,
                  previousVaultId: previous == null
                      ? null
                      : references[previous],
                ),
              ),
            );
          }
          return Ok(entries);
      }
    } on Exception {
      return const Err(WalletBackupStorageFailure());
    }
  }

  @override
  Future<Result<WalletInventoryRecovery, WalletBackupFailure>> restore(
    List<BullVaultBackupEntry> entries,
    List<BackupWallet> wallets,
  ) async {
    try {
      BullVaultBackupEntry.validateInventory(entries, wallets);
    } on FormatException {
      return const Err(WalletBackupIncompleteFailure());
    }
    final inventory = {for (final wallet in wallets) wallet.reference: wallet};
    final ordered = [...entries]
      ..sort(
        (a, b) => a.recoveryPackage.policy.vaultGeneration.compareTo(
          b.recoveryPackage.policy.vaultGeneration,
        ),
      );
    final references = <String, String>{};
    final failed = <String>[];
    for (final entry in ordered) {
      try {
        final previous = entry.recoveryPackage.previousVaultId;
        if (previous != null && !references.containsKey(previous)) {
          throw const FormatException('Predecessor was not recovered');
        }
        final sourceWallet = inventory[entry.reference]!;
        final id = await _database.transaction(() async {
          final existingIds = (await _wallets.fetchAll())
              .map((wallet) => wallet.id)
              .toSet();
          final package = BullVaultRecoveryPackage(
            policy: entry.recoveryPackage.policy,
            previousVaultId: previous == null ? null : references[previous],
          );
          switch (await _vaults.restoreFromRecoveryPackage(
            source: _vaults.encodeRecoveryPackage(package),
            label: sourceWallet.label ?? '',
            status: entry.status,
            network: package.policy.network,
          )) {
            case Err():
              throw const FormatException('Vault was not recovered');
            case Ok(:final value):
              if (references.containsValue(value.wallet.id)) {
                throw const FormatException('Duplicate restored vault');
              }
              if (!existingIds.contains(value.wallet.id)) {
                await _restoreAnnotations(value.wallet.id, sourceWallet);
              }
              return value.wallet.id;
          }
        });
        references[entry.reference] = id;
      } on Exception {
        failed.add(entry.reference);
      }
    }
    return Ok(
      WalletInventoryRecovery(
        walletReferences: references,
        failedReferences: failed,
      ),
    );
  }

  Future<void> _restoreAnnotations(String walletId, BackupWallet source) async {
    if (source.signers.isEmpty && source.birthday == null) return;
    final current = await _wallets.fetch(walletId);
    if (current == null) {
      throw const FormatException('Restored vault is missing');
    }
    for (final annotation in source.signers) {
      if (annotation.signerDevice == null &&
          annotation.registrationName == null) {
        continue;
      }
      final matching = current.signers
          .map((s) => s.toEntity())
          .where(
            (candidate) => candidate.descriptorKeys.any(
              (key) => annotation.descriptorKeys.any((a) => a.xpub == key.xpub),
            ),
          )
          .toList();
      if (matching.length != 1) {
        throw const FormatException('Unknown vault signer');
      }
      final signer = matching.single;
      // Device/name hints never change a cryptographically verified local key.
      if (signer.signer != SignerEntity.local &&
          signer.signerDevice == null &&
          annotation.signerDevice != null) {
        await _signerDevices.updateSignerDevice(
          walletId: walletId,
          signerId: signer.id,
          signerDevice: annotation.signerDevice,
        );
      }
      if (signer.registrationName == null &&
          annotation.registrationName != null) {
        await _signerDevices.updateSignerRegistrationName(
          walletId: walletId,
          signerId: signer.id,
          registrationName: annotation.registrationName!,
        );
      }
    }
    if (current.birthday == null && source.birthday != null) {
      final updated = await _wallets.fetch(walletId);
      if (updated == null) {
        throw const FormatException('Restored vault is missing');
      }
      await _wallets.store(updated.copyWith(birthday: source.birthday));
    }
  }
}
