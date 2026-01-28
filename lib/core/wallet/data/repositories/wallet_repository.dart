import 'dart:async';

import 'package:async/async.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_balances.dart';
import 'package:bb_mobile/core/wallet/domain/ports/electrum_server_port.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';

class WalletRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final BdkWalletDatasource _bdkWallet;
  final LwkWalletDatasource _lwkWallet;
  final ElectrumServerPort _electrumServerPort;

  final _electrumSyncResultController =
      StreamController<ElectrumSyncResult>.broadcast();

  WalletRepository({
    required WalletMetadataDatasource walletMetadataDatasource,
    required BdkWalletDatasource bdkWalletDatasource,
    required LwkWalletDatasource lwkWalletDatasource,
    required ElectrumServerPort electrumServerPort,
  }) : _walletMetadataDatasource = walletMetadataDatasource,
       _bdkWallet = bdkWalletDatasource,
       _lwkWallet = lwkWalletDatasource,
       _electrumServerPort = electrumServerPort {
    // Keep track of the last sync time in the wallet metadata
    _walletSyncFinishedStream.listen(_updateWalletSyncTime);
    // Start auto syncing wallets
  }

  Stream<Wallet> get walletSyncStartedStream => _walletSyncStartedStream
      .asyncMap((walletId) async => await getWallet(walletId))
      .where((event) => event != null)
      .map((event) => event!);

  Stream<Wallet> get walletSyncFinishedStream => _walletSyncFinishedStream
      .asyncMap((walletId) async => await getWallet(walletId))
      .where((event) => event != null)
      .map((event) => event!);

  Stream<ElectrumSyncResult> get electrumSyncResultStream =>
      _electrumSyncResultController.stream;

  bool isWalletSyncing({String? walletId}) =>
      _bdkWallet.isWalletSyncing(walletId: walletId) ||
      _lwkWallet.isWalletSyncing(walletId: walletId);

  Future<Wallet> createWallet({
    required Seed seed,
    required Network network,
    required ScriptType scriptType,
    String? label,
    bool isDefault = false,
    bool sync = false,
    DateTime? birthday,
  }) async {
    // Derive and store the wallet metadata
    final walletLabel =
        isDefault &&
            (network == Network.bitcoinMainnet ||
                network == Network.bitcoinTestnet)
        ? 'Secure Bitcoin'
        : isDefault &&
              (network == Network.liquidMainnet ||
                  network == Network.liquidTestnet)
        ? 'Instant Payments'
        : label;

    final metadata = await WalletMetadataService.deriveFromSeed(
      seed: seed,
      network: network,
      scriptType: scriptType,
      label: walletLabel,
      isDefault: isDefault,
      birthday: birthday,
    );

    if (isDefault) {
      final allWallets = await getWallets(onlyDefaults: true);
      for (final wallet in allWallets) {
        if (wallet.isDefault && wallet.network == metadata.network) {
          throw Exception('Default wallet already exists');
        }
      }
    }

    await _walletMetadataDatasource.store(metadata);
    final balance = await _getBalance(metadata, sync: sync);

    return Wallet(
      origin: metadata.id,
      label: metadata.label,
      network: network,
      isDefault: metadata.isDefault,
      masterFingerprint: metadata.masterFingerprint,
      xpubFingerprint: metadata.xpubFingerprint,
      scriptType: metadata.scriptType,
      xpub: metadata.xpub,
      externalPublicDescriptor: metadata.externalPublicDescriptor,
      internalPublicDescriptor: metadata.internalPublicDescriptor,
      signer: metadata.signer.toEntity(),
      signerDevice: metadata.signerDevice?.toEntity(),
      balanceSat: balance.totalSat,
    );
  }

  Future<Wallet> importDescriptor({
    required WatchOnlyDescriptorEntity watchOnlyDescriptor,
    bool sync = false,
  }) async {
    final metadata = await WalletMetadataService.fromDescriptor(
      watchOnlyDescriptor,
    );

    // Fetch the balance (in the future maybe other details of the wallet too)
    final balance = await _getBalance(metadata, sync: sync);

    final allWallets = await getWallets(onlyDefaults: true);
    for (final wallet in allWallets) {
      if (wallet.id == metadata.id) throw 'Wallet already exists';
    }

    await _walletMetadataDatasource.store(metadata);

    // Return the created wallet entity
    return Wallet(
      origin: metadata.id,
      label: metadata.label,
      network: Network.fromEnvironment(
        isTestnet: metadata.isTestnet,
        isLiquid: metadata.isLiquid,
      ),
      isDefault: metadata.isDefault,
      masterFingerprint: metadata.masterFingerprint,
      xpubFingerprint: metadata.xpubFingerprint,
      scriptType: metadata.scriptType,
      xpub: metadata.xpub,
      externalPublicDescriptor: metadata.externalPublicDescriptor,
      internalPublicDescriptor: metadata.internalPublicDescriptor,
      signer: metadata.signer.toEntity(),
      signerDevice: metadata.signerDevice?.toEntity(),
      balanceSat: balance.totalSat,
    );
  }

  Future<Wallet> importWatchOnlyXpub({
    required String xpub,
    required Network network,
    required ScriptType scriptType,
    required String label,
    bool sync = false,
  }) async {
    final metadata = await WalletMetadataService.deriveFromXpub(
      xpub: xpub,
      network: network,
      scriptType: scriptType,
      label: label,
    );

    // Fetch the balance (in the future maybe other details of the wallet too)
    final balance = await _getBalance(metadata, sync: sync);

    final allWallets = await getWallets(onlyDefaults: true);
    for (final wallet in allWallets) {
      if (wallet.id == metadata.id) throw 'Wallet already exists';
    }

    await _walletMetadataDatasource.store(metadata);

    // Return the created wallet entity
    return Wallet(
      origin: metadata.id,
      label: metadata.label,
      network: Network.fromEnvironment(
        isTestnet: metadata.isTestnet,
        isLiquid: metadata.isLiquid,
      ),
      isDefault: metadata.isDefault,
      masterFingerprint: metadata.masterFingerprint,
      xpubFingerprint: metadata.xpubFingerprint,
      scriptType: metadata.scriptType,
      xpub: metadata.xpub,
      externalPublicDescriptor: metadata.externalPublicDescriptor,
      internalPublicDescriptor: metadata.internalPublicDescriptor,
      signer: metadata.signer.toEntity(),
      signerDevice: metadata.signerDevice?.toEntity(),
      balanceSat: balance.totalSat,
    );
  }

  Future<Wallet?> getWallet(String walletId, {bool sync = false}) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      return null;
    }
    // Get the balance
    final balance = await _getBalance(metadata, sync: sync);

    // Return the wallet entity
    return Wallet(
      origin: metadata.id,
      label: metadata.label,
      network: Network.fromEnvironment(
        isTestnet: metadata.isTestnet,
        isLiquid: metadata.isLiquid,
      ),
      isDefault: metadata.isDefault,
      masterFingerprint: metadata.masterFingerprint,
      xpubFingerprint: metadata.xpubFingerprint,
      scriptType: metadata.scriptType,
      xpub: metadata.xpub,
      externalPublicDescriptor: metadata.externalPublicDescriptor,
      internalPublicDescriptor: metadata.internalPublicDescriptor,
      signer: metadata.signer.toEntity(),
      signerDevice: metadata.signerDevice?.toEntity(),
      balanceSat: balance.totalSat,
      isEncryptedVaultTested: metadata.isEncryptedVaultTested,
      isPhysicalBackupTested: metadata.isPhysicalBackupTested,
      latestEncryptedBackup: metadata.latestEncryptedBackup != null
          ? DateTime.fromMillisecondsSinceEpoch(metadata.latestEncryptedBackup!)
          : null,
      latestPhysicalBackup: metadata.latestPhysicalBackup != null
          ? DateTime.fromMillisecondsSinceEpoch(metadata.latestPhysicalBackup!)
          : null,
    );
  }

  Future<List<Wallet>> getWallets({
    Environment? environment,
    bool? onlyDefaults,
    bool? onlyBitcoin,
    bool? onlyLiquid,
    bool sync = false,
  }) async {
    final metadatas = await _walletMetadataDatasource.fetchAll();
    if (metadatas.isEmpty) return [];

    final filteredWallets = metadatas
        .where(
          (wallet) =>
              (environment == null ||
                  wallet.isMainnet == environment.isMainnet) &&
              (onlyDefaults == null ||
                  onlyDefaults == false ||
                  wallet.isDefault) &&
              (onlyBitcoin == null ||
                  onlyBitcoin == false ||
                  wallet.isBitcoin) &&
              (onlyLiquid == null || onlyLiquid == false || wallet.isLiquid),
        )
        .toList();

    final balances = await Future.wait(
      filteredWallets.map((wallet) => _getBalance(wallet, sync: sync)),
    );

    return filteredWallets
        .asMap()
        .entries
        .map(
          (entry) => Wallet(
            origin: entry.value.id,
            label: entry.value.label,
            network: Network.fromEnvironment(
              isTestnet: entry.value.isTestnet,
              isLiquid: entry.value.isLiquid,
            ),
            isDefault: entry.value.isDefault,
            masterFingerprint: entry.value.masterFingerprint,
            xpubFingerprint: entry.value.xpubFingerprint,
            scriptType: entry.value.scriptType,
            xpub: entry.value.xpub,
            externalPublicDescriptor: entry.value.externalPublicDescriptor,
            internalPublicDescriptor: entry.value.internalPublicDescriptor,
            signer: entry.value.signer.toEntity(),
            signerDevice: entry.value.signerDevice?.toEntity(),
            balanceSat: balances[entry.key].totalSat,
            isEncryptedVaultTested: entry.value.isEncryptedVaultTested,
            isPhysicalBackupTested: entry.value.isPhysicalBackupTested,
            latestEncryptedBackup: entry.value.latestEncryptedBackup != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    entry.value.latestEncryptedBackup!,
                  )
                : null,
            latestPhysicalBackup: entry.value.latestPhysicalBackup != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    entry.value.latestPhysicalBackup!,
                  )
                : null,
          ),
        )
        .toList();
  }

  Future<void> updateEncryptedBackupTime({
    required DateTime? time,
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw WalletError.notFound(walletId);
    }

    await _walletMetadataDatasource.store(
      metadata.copyWith(
        latestEncryptedBackup: time?.millisecondsSinceEpoch,
        isEncryptedVaultTested: time != null,
      ),
    );
  }

  Future<void> updateBackupInfo({
    required bool isEncryptedVaultTested,
    required bool isPhysicalBackupTested,
    required DateTime? latestEncryptedBackup,
    required DateTime? latestPhysicalBackup,
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw WalletError.notFound(walletId);
    }

    await _walletMetadataDatasource.store(
      metadata.copyWith(
        isEncryptedVaultTested: isEncryptedVaultTested,
        isPhysicalBackupTested: isPhysicalBackupTested,
        latestEncryptedBackup: latestEncryptedBackup?.millisecondsSinceEpoch,
        latestPhysicalBackup: latestPhysicalBackup?.millisecondsSinceEpoch,
      ),
    );
  }

  Future<WalletBalances> getWalletBalances({required String walletId}) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw WalletError.notFound(walletId);
    }
    final balance = await _getBalance(metadata);
    return WalletBalances(
      immatureSat: balance.immatureSat.toInt(),
      trustedPendingSat: balance.trustedPendingSat.toInt(),
      untrustedPendingSat: balance.untrustedPendingSat.toInt(),
      confirmedSat: balance.confirmedSat.toInt(),
      spendableSat: balance.spendableSat.toInt(),
      totalSat: balance.totalSat.toInt(),
    );
  }

  Future<void> deleteWallet({required String walletId}) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) throw WalletError.notFound(walletId);

    if (metadata.isBitcoin) {
      await _bdkWallet.delete(wallet: WalletModel.fromMetadata(metadata));
    }

    if (metadata.isLiquid) {
      await _lwkWallet.delete(wallet: WalletModel.fromMetadata(metadata));
    }

    // Delete wallet metadata from database
    await _walletMetadataDatasource.delete(walletId);
  }

  Stream<String> get _walletSyncStartedStream => StreamGroup.merge([
    _bdkWallet.walletSyncStartedStream,
    _lwkWallet.walletSyncStartedStream,
  ]);

  Stream<String> get _walletSyncFinishedStream => StreamGroup.merge([
    _bdkWallet.walletSyncFinishedStream,
    _lwkWallet.walletSyncFinishedStream,
  ]);

  Future<void> _updateWalletSyncTime(String walletId) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      return;
    }

    final updatedWalletMetadata = metadata.copyWith(syncedAt: DateTime.now());

    await _walletMetadataDatasource.store(updatedWalletMetadata);
  }

  Future<BalanceModel> _getBalance(
    WalletMetadataModel metadata, {
    bool sync = false,
  }) async {
    BalanceModel balance;
    if (metadata.isLiquid) {
      final wallet = WalletModel.publicLwk(
        combinedCtDescriptor: metadata.externalPublicDescriptor,
        isTestnet: metadata.isTestnet,
        id: metadata.id,
      );

      if (sync) {
        await _syncWallet(wallet);
      }

      balance = await _lwkWallet.getBalance(wallet: wallet);
    } else {
      final wallet = WalletModel.publicBdk(
        externalDescriptor: metadata.externalPublicDescriptor,
        internalDescriptor: metadata.internalPublicDescriptor,
        isTestnet: metadata.isTestnet,
        id: metadata.id,
      );

      if (sync) {
        await _syncWallet(wallet);
      }

      balance = await _bdkWallet.getBalance(wallet: wallet);
    }

    return balance;
  }

  Future<void> sync(Wallet wallet) async {
    final walletModel = WalletModel.fromMetadata(
      WalletMetadataModel(
        id: wallet.id,
        masterFingerprint: wallet.masterFingerprint,
        xpubFingerprint: wallet.xpubFingerprint,
        isEncryptedVaultTested: wallet.isEncryptedVaultTested,
        isPhysicalBackupTested: wallet.isPhysicalBackupTested,
        externalPublicDescriptor: wallet.externalPublicDescriptor,
        internalPublicDescriptor: wallet.internalPublicDescriptor,
        xpub: wallet.xpub,
        isDefault: wallet.isDefault,
        label: wallet.label,
        signer: Signer.fromEntity(wallet.signer),
      ),
    );
    await _syncWallet(walletModel);
  }

  Future<void> _syncWallet(WalletModel wallet) async {
    try {
      final isLiquid = wallet is PublicLwkWalletModel;
      final electrumServers = await _electrumServerPort.getElectrumServers(
        isTestnet: wallet.isTestnet,
        isLiquid: isLiquid,
      );

      for (int i = 0; i < electrumServers.length; i++) {
        final electrumServer = electrumServers[i];
        try {
          if (isLiquid) {
            await _lwkWallet.sync(
              wallet: wallet,
              electrumServer: electrumServer,
            );
          } else {
            await _bdkWallet.sync(
              wallet: wallet,
              electrumServer: electrumServer,
            );
          }
          _electrumSyncResultController.add(
            ElectrumSyncResult(isLiquid: isLiquid, success: true),
          );
          return;
        } catch (e, stackTrace) {
          log.severe(
            message:
                'sync wallet error with electrum server: ${electrumServer.url}',
            error: e,
            trace: stackTrace,
          );
          if (i == electrumServers.length - 1) {
            _electrumSyncResultController.add(
              ElectrumSyncResult(isLiquid: isLiquid, success: false),
            );
            throw Exception('All Electrum servers failed to sync.');
          }
          continue;
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> isTorRequired() async {
    final defaultWallets = await getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
      environment: Environment.mainnet,
    );

    if (defaultWallets.isEmpty) return false;

    return defaultWallets.first.latestEncryptedBackup != null;
  }

  Future<int> getAmountSentToAddress({
    required String psbtOrPset,
    required String address,
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    if (metadata.isLiquid) {
      final wallet = WalletModel.publicLwk(
        combinedCtDescriptor: metadata.externalPublicDescriptor,
        isTestnet: metadata.isTestnet,
        id: metadata.id,
      );
      return await _lwkWallet.getAmountSentToAddress(
        psbtOrPset,
        address,
        wallet: wallet,
      );
    } else {
      return await _bdkWallet.getAmountSentToAddress(
        psbtOrPset,
        address,
        isTestnet: metadata.isTestnet,
      );
    }
  }
}
