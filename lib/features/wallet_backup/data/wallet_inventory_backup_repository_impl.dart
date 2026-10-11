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
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_inventory_backup_repository.dart';

final class WalletInventoryBackupRepositoryImpl
    implements WalletInventoryBackupRepository {
  final SqliteDatabase _database;
  final WalletMetadataDatasource _wallets;
  final BitcoinDescriptorPort _descriptors;
  final SeedVerificationPort _seeds;
  final BullVaultFacade _vaults;
  final WalletSignerDevicePort _signerDevices;

  const WalletInventoryBackupRepositoryImpl({
    required this._database,
    required this._wallets,
    required this._descriptors,
    required this._seeds,
    required this._vaults,
    required this._signerDevices,
  });

  @override
  Future<Result<WalletInventoryRecovery, WalletBackupFailure>> restore(
    List<BackupWallet> wallets, {
    Map<String, String?> initialWalletLabels = const {},
  }) async {
    if (wallets.map((entry) => entry.reference).toSet().length !=
        wallets.length) {
      return const Err(WalletBackupIncompleteFailure());
    }
    final references = <String, String>{};
    final failed = <String>[];
    for (final entry in wallets) {
      try {
        final id = await _restoreOne(
          entry,
          references.values.toSet(),
          initialWalletLabels,
        );
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

  Future<String> _restoreOne(
    BackupWallet entry,
    Set<String> resolved,
    Map<String, String?> initialWalletLabels,
  ) async {
    final descriptor = _canonical(entry.publicDescriptor, entry.network);
    return _database.transaction(() async {
      final installed = await _wallets.fetchAll();
      final matches = installed
          .where((wallet) => _matches(wallet, entry.network, descriptor))
          .toList();
      if (matches.length > 1) throw const FormatException('Ambiguous wallet');
      if (matches.length == 1) {
        final id = matches.single.id;
        if (resolved.contains(id)) {
          throw const FormatException('Duplicate wallet');
        }
        // Only this physical restore's new, still-unedited label can be filled from the backup.
        final current = matches.single;
        if (initialWalletLabels.containsKey(id) &&
            current.label == initialWalletLabels[id] &&
            entry.label != null) {
          await _wallets.store(current.copyWith(label: entry.label));
        }
        return id;
      }
      if (!entry.network.isBitcoin ||
          installed.any((wallet) => wallet.id == entry.reference)) {
        throw const FormatException('Wallet must be restored separately');
      }
      final parsed = _descriptors.parseBitcoinDescriptor(
        descriptor: descriptor,
        network: entry.network,
      );
      final annotations = await _annotations(
        entry.signers,
        parsed.descriptorKeys,
      );
      final imported = await _descriptors.importDescriptor(
        descriptor: descriptor,
        network: entry.network,
        label: entry.label ?? '',
        signers: annotations,
        isHidden: entry.isHidden,
      );
      final current = await _wallets.fetch(imported.id);
      if (current == null ||
          !_matches(current, entry.network, descriptor) ||
          resolved.contains(current.id)) {
        throw const FormatException('Wallet import did not persist');
      }
      // No importer/default-wallet contract changes: the existing owner stores
      // this one preference while the transaction excludes concurrent writes.
      if (current.birthday == null && entry.birthday != null) {
        await _wallets.store(current.copyWith(birthday: entry.birthday));
      }
      return current.id;
    });
  }

  String _canonical(String descriptor, Network network) => network.isBitcoin
      ? _descriptors
            .parseBitcoinDescriptor(descriptor: descriptor, network: network)
            .descriptor
      : descriptor;

  bool _matches(
    WalletMetadataModel wallet,
    Network network,
    String descriptor,
  ) {
    if (wallet.network != network) return false;
    try {
      return _canonical(wallet.publicDescriptor, network) == descriptor;
    } on Exception {
      return false;
    }
  }

  Future<List<WalletSigner>> _annotations(
    List<WalletSigner> source,
    List<WalletDescriptorKey> parsed,
  ) async {
    if (source.isEmpty) return [];
    final sourceKeys = source
        .expand((signer) => signer.descriptorKeys)
        .toList();
    if (source.map((signer) => signer.id).toSet().length != source.length ||
        sourceKeys.length != parsed.length ||
        sourceKeys.map((key) => key.id).toSet().length != sourceKeys.length) {
      throw const FormatException('Invalid signer annotations');
    }
    final result = <WalletSigner>[];
    for (final signer in source) {
      final keys = <WalletDescriptorKey>[];
      for (final annotation in signer.descriptorKeys) {
        final actual = parsed
            .where((key) => key.id == annotation.id)
            .singleOrNull;
        if (actual == null ||
            actual.xpub != annotation.xpub ||
            actual.masterFingerprint != annotation.masterFingerprint ||
            actual.derivationPath != annotation.derivationPath ||
            actual.descriptorPath != annotation.descriptorPath) {
          throw const FormatException('Signer does not match descriptor');
        }
        keys.add(
          actual.copyWith(
            signerId: signer.id,
            requiresPassphrase: annotation.requiresPassphrase,
          ),
        );
      }
      final fingerprint =
          signer.localSeedFingerprint ?? keys.first.masterFingerprint;
      final local =
          signer.signer == SignerEntity.local &&
          keys.every(
            (key) => key.derivationPath != null && !key.requiresPassphrase,
          ) &&
          await _seeds.matchesXpubs(
            fingerprint: fingerprint,
            keys: [
              for (final key in keys)
                (derivationPath: key.derivationPath!, xpub: key.xpub),
            ],
          );
      result.add(
        WalletSigner(
          id: signer.id,
          signer: local
              ? SignerEntity.local
              : signer.signer == SignerEntity.remote
              ? SignerEntity.remote
              : SignerEntity.none,
          signerDevice: local ? null : signer.signerDevice,
          registrationName: signer.registrationName,
          localSeedFingerprint: local ? fingerprint : null,
          descriptorKeys: keys,
        ),
      );
    }
    return result;
  }

  @override
  Stream<void> get vaultChanges => _vaults.watchRecords();

  @override
  Future<Result<List<BullVaultBackupEntry>, WalletBackupFailure>> captureVaults(
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
  Future<Result<WalletInventoryRecovery, WalletBackupFailure>> restoreVaults(
    List<BullVaultBackupEntry> entries,
    List<BackupWallet> wallets, {
    bool Function()? abandoned,
  }) async {
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
      if (abandoned?.call() ?? false) {
        failed.add(entry.reference);
        continue;
      }
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
            label: sourceWallet.label?.trim().isNotEmpty == true
                ? sourceWallet.label!
                : entry.reference,
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
