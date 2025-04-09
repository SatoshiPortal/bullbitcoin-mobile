import 'dart:async';
import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
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

  // Single StreamController to handle all wallet updates
  final _walletUpdatesController = StreamController<List<Wallet>>.broadcast();

  WalletRepositoryImpl({
    required WalletMetadataDatasource walletMetadataDatasource,
    required BdkWalletDatasource bdkWalletDatasource,
    required LwkWalletDatasource lwkWalletDatasource,
    required ElectrumServerStorageDatasource electrumServerStorageDatasource,
  })  : _walletMetadata = walletMetadataDatasource,
        _bdkWallet = bdkWalletDatasource,
        _lwkWallet = lwkWalletDatasource,
        _electrumServerStorage = electrumServerStorageDatasource {
    // Listen to wallet sync completion events from both datasources
    _bdkWallet.syncedWallets.listen(_handleWalletSyncCompleted);
    _lwkWallet.syncedWallets.listen(_handleWalletSyncCompleted);
  }

  // Check if a wallet is currently syncing by using the wallet model's dbName
  bool isWalletSyncing(WalletMetadataModel metadata) {
    if (metadata.isLiquid) {
      return _lwkWallet.isWalletSyncing(metadata.id);
    } else {
      return _bdkWallet.isWalletSyncing(metadata.id);
    }
  }

  // Get active sync for a wallet using the wallet model's dbName
  Future<void>? getActiveSyncForWallet(WalletMetadataModel metadata) {
    if (metadata.isLiquid) {
      return _lwkWallet.getActiveSyncForWallet(metadata.id);
    } else {
      return _bdkWallet.getActiveSyncForWallet(metadata.id);
    }
  }

  // Handler for wallet sync completion
  Future<void> _handleWalletSyncCompleted(String walletId) async {
    // When sync completes, update the wallet data and emit to stream
    try {
      final metadata = await _walletMetadata.get(walletId);
      if (metadata != null) {
        final wallet = await _buildWalletFromMetadata(metadata, sync: false);

        // Emit the single updated wallet as a list with one element
        _walletUpdatesController.add([wallet]);

        // Also update the full wallets list
        _updateWalletsStream();
      }
    } catch (e) {
      // Handle any errors during the update process
    }
  }

  // Helper method to build a Wallet entity from metadata
  Future<Wallet> _buildWalletFromMetadata(
    WalletMetadataModel metadata, {
    required bool sync,
  }) async {
    // Get initial balance without waiting for sync
    final balance = await _getBalance(metadata, sync: false);

    // Create the wallet entity
    final wallet = Wallet(
      id: metadata.id,
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

    // Start the sync process if requested and not already syncing
    if (sync && !isWalletSyncing(metadata)) {
      _startWalletSync(metadata);
    }
    return wallet;
  }

  // Helper method to start wallet sync process
  Future<void> _startWalletSync(WalletMetadataModel metadata) async {
    try {
      final electrumServer = await _electrumServerStorage.getByProvider(
            ElectrumServerProvider.blockstream,
            network: Network.fromEnvironment(
              isTestnet: metadata.isTestnet,
              isLiquid: metadata.isLiquid,
            ),
          ) ??
          ElectrumServerModel.blockstream(
            isTestnet: metadata.isTestnet,
            isLiquid: metadata.isLiquid,
          );

      if (metadata.isLiquid) {
        final wallet = PublicLwkWalletModel(
          combinedCtDescriptor: metadata.externalPublicDescriptor,
          isTestnet: metadata.isTestnet,
          dbName: metadata.id,
        );
        await _lwkWallet.sync(wallet: wallet, electrumServer: electrumServer);
      } else {
        final wallet = PublicBdkWalletModel(
          externalDescriptor: metadata.externalPublicDescriptor,
          internalDescriptor: metadata.internalPublicDescriptor,
          isTestnet: metadata.isTestnet,
          dbName: metadata.id,
        );
        await _bdkWallet.sync(wallet: wallet, electrumServer: electrumServer);
      }
    } catch (e) {
      // Error handling is managed by the datasources
    }
  }

  // Method to update the wallets stream with the full list
  Future<void> _updateWalletsStream() async {
    final wallets = await getWallets();
    _walletUpdatesController.add(wallets);
  }

  @override
  Future<Stream<List<Wallet>>> get wallets async {
    return _walletUpdatesController.stream;
  }

  @override
  Future<Wallet> createWallet({
    required Seed seed,
    required Network network,
    required ScriptType scriptType,
    String label = '',
    bool isDefault = false,
    bool sync = true,
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

    // Create the wallet immediately
    final wallet = await _buildWalletFromMetadata(metadata, sync: sync);

    // Emit the newly created wallet as a list with one element
    _walletUpdatesController.add([wallet]);

    return wallet;
  }

  @override
  Future<Wallet> importWatchOnlyWallet({
    required String xpub,
    required Network network,
    required ScriptType scriptType,
    required String label,
    bool sync = true,
  }) async {
    final metadata = await _walletMetadata.deriveFromXpub(
      xpub: xpub,
      network: network,
      scriptType: scriptType,
      label: label,
    );
    await _walletMetadata.store(metadata);

    // Create the wallet immediately
    final wallet = await _buildWalletFromMetadata(metadata, sync: sync);

    // Emit the newly imported wallet as a list with one element
    _walletUpdatesController.add([wallet]);

    return wallet;
  }

  @override
  Future<Wallet> getWallet(String walletId, {bool sync = false}) async {
    final metadata = await _walletMetadata.get(walletId);

    if (metadata == null) {
      throw WalletNotFoundException(walletId);
    }

    // Create and return wallet immediately
    final wallet = await _buildWalletFromMetadata(metadata, sync: sync);

    return wallet;
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

    // Get initial wallets without waiting for sync
    final initialWallets = await Future.wait(
      filteredWallets.map(
        (metadata) => _buildWalletFromMetadata(
          metadata,
          sync: sync,
        ),
      ),
    );

    return initialWallets;
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

    // Update the wallet in stream after backup time changes
    final updatedWallet = await getWallet(
      walletId,
    );
    _walletUpdatesController.add([updatedWallet]);
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

    // Update the wallet in stream after backup info changes
    final updatedWallet = await getWallet(
      walletId,
    );
    _walletUpdatesController.add([updatedWallet]);
  }

  Future<BalanceModel> _getBalance(
    WalletMetadataModel metadata, {
    bool sync = true,
  }) async {
    BalanceModel balance;
    if (metadata.isLiquid) {
      final wallet = PublicLwkWalletModel(
        combinedCtDescriptor: metadata.externalPublicDescriptor,
        isTestnet: metadata.isTestnet,
        dbName: metadata.id,
      );

      if (sync && !_lwkWallet.isWalletSyncing(metadata.id)) {
        // Don't wait for sync here, we'll start it in background
        _startWalletSync(metadata);
      }

      balance = await _lwkWallet.getBalance(wallet: wallet);
    } else {
      final wallet = PublicBdkWalletModel(
        externalDescriptor: metadata.externalPublicDescriptor,
        internalDescriptor: metadata.internalPublicDescriptor,
        isTestnet: metadata.isTestnet,
        dbName: metadata.id,
      );

      if (sync && !_bdkWallet.isWalletSyncing(metadata.id)) {
        // Don't wait for sync here, we'll start it in background
        _startWalletSync(metadata);
      }

      balance = await _bdkWallet.getBalance(wallet: wallet);
    }

    return balance;
  }
}

class WalletNotFoundException implements Exception {
  final String message;

  const WalletNotFoundException(this.message);
}
