import 'dart:async';

import 'package:async/async.dart';
import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/public_wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  final WalletMetadataDatasource _walletMetadata;
  final BdkWalletDatasource _bdkWallet;
  final LwkWalletDatasource _lwkWallet;
  final ElectrumServerStorageDatasource _electrumServerStorage;

  WalletRepositoryImpl({
    required WalletMetadataDatasource walletMetadataDatasource,
    required BdkWalletDatasource bdkWalletDatasource,
    required LwkWalletDatasource lwkWalletDatasource,
    required ElectrumServerStorageDatasource electrumServerStorageDatasource,
  })  : _walletMetadata = walletMetadataDatasource,
        _bdkWallet = bdkWalletDatasource,
        _lwkWallet = lwkWalletDatasource,
        _electrumServerStorage = electrumServerStorageDatasource {
    // Keep track of the last sync time in the wallet metadata
    _walletSyncFinishedStream.listen(_updateWalletSyncTime);
    // Start auto syncing wallets
    _startAutoSyncing();
  }

  @override
  Stream<Wallet> get walletSyncStartedStream => _walletSyncStartedStream
      .asyncMap((walletId) async => await getWallet(walletId));

  @override
  Stream<Wallet> get walletSyncFinishedStream => _walletSyncFinishedStream
      .asyncMap((walletId) async => await getWallet(walletId));

  @override
  bool get isAnyWalletSyncing =>
      _bdkWallet.isAnyWalletSyncing || _lwkWallet.isAnyWalletSyncing;

  @override
  Future<Wallet> createWallet({
    required Seed seed,
    required Network network,
    required ScriptType scriptType,
    String label = '',
    bool isDefault = false,
    bool sync = false,
  }) async {
    // Derive and store the wallet metadata
    final walletLabel = isDefault &&
            (network == Network.bitcoinMainnet ||
                network == Network.bitcoinTestnet)
        ? 'Secure Bitcoin'
        : isDefault &&
                (network == Network.liquidMainnet ||
                    network == Network.liquidTestnet)
            ? 'Instant Payments'
            : label;
    final metadata = await _walletMetadata.deriveFromSeed(
      seed: seed,
      network: network,
      scriptType: scriptType,
      label: walletLabel,
      isDefault: isDefault,
    );
    await _walletMetadata.store(metadata);

    // Get the balance
    final balance = await _getBalance(metadata, sync: sync);

    // Return the created wallet entity
    return Wallet(
      origin: metadata.origin,
      label: metadata.label,
      network: network,
      isDefault: metadata.isDefault,
      masterFingerprint: metadata.masterFingerprint,
      xpubFingerprint: metadata.xpubFingerprint,
      scriptType: ScriptType.fromName(metadata.scriptType),
      xpub: metadata.xpub,
      externalPublicDescriptor: metadata.externalPublicDescriptor,
      internalPublicDescriptor: metadata.internalPublicDescriptor,
      source: WalletSource.fromName(metadata.source),
      balanceSat: balance.totalSat,
    );
  }

  @override
  Future<Wallet> importWatchOnlyWallet({
    required String xpub,
    required Network network,
    required ScriptType scriptType,
    required String label,
    bool sync = false,
  }) async {
    final metadata = await _walletMetadata.deriveFromXpub(
      xpub: xpub,
      network: network,
      scriptType: scriptType,
      label: label,
    );
    await _walletMetadata.store(metadata);

    // Fetch the balance (in the future maybe other details of the wallet too)
    final balance = await _getBalance(metadata, sync: sync);

    // Return the created wallet entity
    return Wallet(
      origin: metadata.origin,
      label: metadata.label,
      network: Network.fromEnvironment(
        isTestnet: metadata.isTestnet,
        isLiquid: metadata.isLiquid,
      ),
      isDefault: metadata.isDefault,
      masterFingerprint: metadata.masterFingerprint,
      xpubFingerprint: metadata.xpubFingerprint,
      scriptType: ScriptType.fromName(metadata.scriptType),
      xpub: metadata.xpub,
      externalPublicDescriptor: metadata.externalPublicDescriptor,
      internalPublicDescriptor: metadata.internalPublicDescriptor,
      source: WalletSource.fromName(metadata.source),
      balanceSat: balance.totalSat,
    );
  }

  @override
  Future<Wallet> getWallet(String walletId, {bool sync = false}) async {
    final metadata = await _walletMetadata.get(walletId);

    if (metadata == null) {
      throw throw WalletNotFoundException(walletId);
    }
    // Get the balance
    final balance = await _getBalance(metadata, sync: sync);

    // Return the wallet entity
    return Wallet(
      origin: metadata.origin,
      label: metadata.label,
      network: Network.fromEnvironment(
        isTestnet: metadata.isTestnet,
        isLiquid: metadata.isLiquid,
      ),
      isDefault: metadata.isDefault,
      masterFingerprint: metadata.masterFingerprint,
      xpubFingerprint: metadata.xpubFingerprint,
      scriptType: ScriptType.fromName(metadata.scriptType),
      xpub: metadata.xpub,
      externalPublicDescriptor: metadata.externalPublicDescriptor,
      internalPublicDescriptor: metadata.internalPublicDescriptor,
      source: WalletSource.fromName(metadata.source),
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

  @override
  Future<List<Wallet>> getWallets({
    Environment? environment,
    bool? onlyDefaults,
    bool? onlyBitcoin,
    bool? onlyLiquid,
    bool sync = false,
  }) async {
    final wallets = await _walletMetadata.getAll();
    if (wallets.isEmpty) {
      return [];
    }

    final filteredWallets = wallets
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
            origin: entry.value.origin,
            label: entry.value.label,
            network: Network.fromEnvironment(
              isTestnet: entry.value.isTestnet,
              isLiquid: entry.value.isLiquid,
            ),
            isDefault: entry.value.isDefault,
            masterFingerprint: entry.value.masterFingerprint,
            xpubFingerprint: entry.value.xpubFingerprint,
            scriptType: ScriptType.fromName(entry.value.scriptType),
            xpub: entry.value.xpub,
            externalPublicDescriptor: entry.value.externalPublicDescriptor,
            internalPublicDescriptor: entry.value.internalPublicDescriptor,
            source: WalletSource.fromName(entry.value.source),
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

  @override
  Future<void> updateEncryptedBackupTime(
    DateTime time, {
    required String walletId,
  }) async {
    final metadata = await _walletMetadata.get(walletId);
    if (metadata == null) {
      throw WalletNotFoundException(walletId);
    }
    await _walletMetadata.store(
      metadata.copyWith(
        latestEncryptedBackup: time.millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Future<void> updateBackupInfo({
    required bool isEncryptedVaultTested,
    required bool isPhysicalBackupTested,
    required DateTime? latestEncryptedBackup,
    required DateTime? latestPhysicalBackup,
    required String walletId,
  }) async {
    final metadata = await _walletMetadata.get(walletId);
    if (metadata == null) {
      throw WalletNotFoundException(walletId);
    }
    await _walletMetadata.store(
      metadata.copyWith(
        isEncryptedVaultTested: isEncryptedVaultTested,
        isPhysicalBackupTested: isPhysicalBackupTested,
        latestEncryptedBackup: latestEncryptedBackup?.millisecondsSinceEpoch,
        latestPhysicalBackup: latestPhysicalBackup?.millisecondsSinceEpoch,
      ),
    );
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
    final walletMetadata = await _walletMetadata.get(walletId);
    if (walletMetadata == null) {
      return;
    }
    final updatedWalletMetadata = walletMetadata.copyWith(
      syncedAt: DateTime.now(),
    );

    await _walletMetadata.store(updatedWalletMetadata);
  }

  Future<void> _startAutoSyncing() async {
    // TODO: get from constants
    const autoSyncInterval =
        Duration(seconds: SettingsConstants.autoSyncIntervalSeconds);

    Timer.periodic(
      autoSyncInterval,
      (timer) async {
        final walletsMetadata = await _walletMetadata.getAll();
        for (final metadata in walletsMetadata) {
          // Only sync if the time since the last sync is greater than the interval
          if (metadata.syncedAt == null ||
              metadata.syncedAt!
                      .compareTo(DateTime.now().subtract(autoSyncInterval)) <=
                  0) {
            final wallet = metadata.isLiquid
                ? PublicLwkWalletModel(
                    combinedCtDescriptor: metadata.externalPublicDescriptor,
                    isTestnet: metadata.isTestnet,
                    id: metadata.id,
                  )
                : PublicBdkWalletModel(
                    externalDescriptor: metadata.externalPublicDescriptor,
                    internalDescriptor: metadata.internalPublicDescriptor,
                    isTestnet: metadata.isTestnet,
                    id: metadata.id,
                  );
            await _syncWallet(wallet);
          }
        }
      },
    );
  }

  Future<BalanceModel> _getBalance(
    WalletMetadataModel metadata, {
    bool sync = false,
  }) async {
    BalanceModel balance;
    if (metadata.isLiquid) {
      final wallet = PublicLwkWalletModel(
        combinedCtDescriptor: metadata.externalPublicDescriptor,
        isTestnet: metadata.isTestnet,
        id: metadata.id,
      );

      if (sync) {
        await _syncWallet(wallet);
      }

      balance = await _lwkWallet.getBalance(wallet: wallet);
    } else {
      final wallet = PublicBdkWalletModel(
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

  Future<void> _syncWallet(PublicWalletModel wallet) async {
    final isLiquid = wallet is PublicLwkWalletModel;
    final electrumServer = await _electrumServerStorage.getByProvider(
          ElectrumServerProvider.blockstream,
          network: Network.fromEnvironment(
            isTestnet: wallet.isTestnet,
            isLiquid: isLiquid,
          ),
        ) ??
        ElectrumServerModel.blockstream(
          isTestnet: wallet.isTestnet,
          isLiquid: isLiquid,
        );
    if (isLiquid) {
      await _lwkWallet.sync(wallet: wallet, electrumServer: electrumServer);
    } else {
      await _bdkWallet.sync(wallet: wallet, electrumServer: electrumServer);
    }
  }
}

class WalletNotFoundException implements Exception {
  final String message;

  const WalletNotFoundException(this.message);
}
