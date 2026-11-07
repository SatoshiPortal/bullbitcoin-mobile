import 'package:primitives/primitives.dart' show Fingerprint;
import 'dart:async';
import 'package:bb_mobile/features/wallet/data/wallet_native_runtime.dart';
import 'package:transaction_sync/read.dart';
import 'package:transaction_sync/transaction_sync.dart'
    show TransactionSyncBusyFailure;

import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_balances.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:meta/meta.dart';

class WalletRepository implements SeedReferencePort {
  final WalletNativeLifecycle? _native;
  final _unavailable = <String, Type>{};
  int _invalidCatalogCount = 0;
  final WalletMetadataDatasource _walletMetadataDatasource;
  final BdkWalletDatasource _bdkWallet;
  final LwkWalletDatasource _lwkWallet;
  final Future<void> Function(WalletMetadataModel, {bool discover}) _syncWallet;
  final bool Function({String? walletId}) _isSyncing;
  final Stream<String> _walletSyncStartedStream;
  final Stream<String> _walletSyncFinishedStream;
  final Stream<ElectrumSyncResult> electrumSyncResultStream;

  WalletRepository({
    this._native,
    required this._walletMetadataDatasource,
    required BdkWalletDatasource bdkWalletDatasource,
    required LwkWalletDatasource lwkWalletDatasource,
    required Future<void> Function(WalletMetadataModel, {bool discover})
    synchronize,
    required this._isSyncing,
    required Stream<String> syncStarted,
    required Stream<String> syncFinished,
    required this.electrumSyncResultStream,
  }) : _bdkWallet = bdkWalletDatasource,
       _lwkWallet = lwkWalletDatasource,
       _syncWallet = synchronize,
       _walletSyncStartedStream = syncStarted,
       _walletSyncFinishedStream = syncFinished {
    // Keep track of the last sync time in the wallet metadata
    _walletSyncFinishedStream.listen(_updateWalletSyncTime);
    // Start auto syncing wallets
  }

  Stream<Wallet> get walletSyncStartedStream => _walletSyncStartedStream
      .asyncMap<Result<Wallet, WalletFailure>>((id) => getWallet(id))
      .map<Wallet?>((result) => result.fold((w) => w, (_) => null))
      .where((wallet) => wallet != null)
      .map((wallet) => wallet!);

  Stream<Wallet> get walletSyncFinishedStream => _walletSyncFinishedStream
      .asyncMap<Result<Wallet, WalletFailure>>((id) => getWallet(id))
      .map<Wallet?>((result) => result.fold((w) => w, (_) => null))
      .where((wallet) => wallet != null)
      .map((wallet) => wallet!);

  @useResult
  Result<bool, WalletFailure> isWalletSyncing({String? walletId}) {
    try {
      return Ok(_isSyncing(walletId: walletId));
    } catch (e, st) {
      log.severe(message: 'isWalletSyncing failed', error: e, trace: st);
      return Err(_classify(e, 'isWalletSyncing'));
    }
  }

  Future<Wallet> createWallet({
    required Secret secret,
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

    final metadata = await WalletMetadataService.deriveFromSecret(
      secret: secret,
      network: network,
      scriptType: scriptType,
      label: walletLabel,
      isDefault: isDefault,
      birthday: birthday,
    );

    if (isDefault) {
      final allWallets = (await _walletMetadataDatasource.fetchAll()).where(
        (row) => row.isDefault,
      );
      for (final wallet in allWallets) {
        if (wallet.isDefault &&
            wallet.isLiquid == metadata.isLiquid &&
            wallet.isTestnet == metadata.isTestnet) {
          throw Exception('Default wallet already exists');
        }
      }
    }

    await _provision(metadata);
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
      confirmedBalanceSat: balance.confirmedSat,
    );
  }

  Future<Wallet> importDescriptor({
    required WatchOnlyDescriptorEntity watchOnlyDescriptor,
    bool sync = false,
  }) async {
    final metadata = await WalletMetadataService.fromDescriptor(
      watchOnlyDescriptor,
    );

    final allWallets = await _walletMetadataDatasource.fetchAll();
    for (final wallet in allWallets) {
      if (wallet.id == metadata.id) {
        throw WalletAlreadyExistsException(metadata.id);
      }
    }

    await _provision(metadata);
    final balance = await _getBalance(metadata, sync: sync);

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
      confirmedBalanceSat: balance.confirmedSat,
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

    final allWallets = await _walletMetadataDatasource.fetchAll();
    for (final wallet in allWallets) {
      if (wallet.id == metadata.id) {
        throw WalletAlreadyExistsException(metadata.id);
      }
    }

    await _provision(metadata);
    final balance = await _getBalance(metadata, sync: sync);

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
      confirmedBalanceSat: balance.confirmedSat,
    );
  }

  @useResult
  Future<Result<Wallet, WalletFailure>> getWallet(
    String walletId, {
    bool sync = false,
  }) async {
    try {
      final wallet = await _readWallet(walletId, sync: sync);
      // A missing wallet is a modeled outcome, not an exception: the id simply
      // is not in the store.
      return wallet == null
          ? const Err(WalletNotFoundFailure('no metadata for the wallet id'))
          : Ok(wallet);
    } catch (e, st) {
      _reportReadFailure(e, st, 'getWallet');
      return Err(_classify(e, 'getWallet'));
    }
  }

  Future<Wallet?> _readWallet(String walletId, {bool sync = false}) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      return null;
    }
    return _walletFromMetadata(
      metadata,
      sync
          ? await _getBalance(metadata, sync: true)
          : await _readBalance(metadata, sync: false),
    );
  }

  Future<BalanceModel?> _readBalance(
    WalletMetadataModel metadata, {
    required bool sync,
  }) async {
    try {
      final balance = await _getBalance(metadata, sync: sync);
      if (_unavailable.remove(metadata.id) != null) {
        log.fine('Wallet balance available');
      }
      return balance;
    } catch (error) {
      if (_unavailable[metadata.id] != error.runtimeType) {
        _unavailable[metadata.id] = error.runtimeType;
        log.warning('Wallet balance unavailable category=${error.runtimeType}');
      }
      return null;
    }
  }

  Wallet _walletFromMetadata(
    WalletMetadataModel metadata,
    BalanceModel? balance,
  ) {
    final encrypted = metadata.latestEncryptedBackup;
    final physical = metadata.latestPhysicalBackup;
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
      balanceSat: balance?.totalSat,
      confirmedBalanceSat: balance?.confirmedSat,
      isEncryptedVaultTested: metadata.isEncryptedVaultTested,
      isPhysicalBackupTested: metadata.isPhysicalBackupTested,
      latestEncryptedBackup: encrypted != null
          ? DateTime.fromMillisecondsSinceEpoch(encrypted)
          : null,
      latestPhysicalBackup: physical != null
          ? DateTime.fromMillisecondsSinceEpoch(physical)
          : null,
    );
  }

  @useResult
  Future<Result<List<Wallet>, WalletFailure>> getWallets({
    Environment? environment,
    bool? onlyDefaults,
    bool? onlyBitcoin,
    bool? onlyLiquid,
    bool sync = false,
  }) async {
    try {
      return Ok(
        await _readWallets(
          environment: environment,
          onlyDefaults: onlyDefaults,
          onlyBitcoin: onlyBitcoin,
          onlyLiquid: onlyLiquid,
          sync: sync,
        ),
      );
    } catch (e, st) {
      _reportReadFailure(e, st, 'getWallets');
      return Err(_classify(e, 'getWallets'));
    }
  }

  /// Exhaustive custody references, independent of origin and native reads.
  /// A partial result must never authorize destruction of a secret.
  @override
  @useResult
  Future<Result<Set<Fingerprint>, WalletFailure>>
  getCustodyFingerprints() async {
    try {
      final rows = await _walletMetadataDatasource.fetchAll();
      final fingerprints = <Fingerprint>{};
      for (final row in rows) {
        if (row.signer != Signer.local) continue;
        final fingerprint = Fingerprint.tryParse(row.masterFingerprint);
        if (fingerprint == null) {
          return const Err(WalletStorageFailure('invalid custody reference'));
        }
        fingerprints.add(fingerprint);
      }
      return Ok(fingerprints);
    } catch (error) {
      log.warning(
        'Wallet custody references unavailable category=${error.runtimeType}',
      );
      return const Err(WalletStorageFailure('custody references unavailable'));
    }
  }

  void _reportReadFailure(Object error, StackTrace trace, String operation) {
    if (error is WalletSnapshotException &&
        error.failure is TransactionSyncBusyFailure) {
      log.warning('Wallet read deferred operation=$operation category=busy');
    } else {
      log.severe(
        message: 'Wallet read failed operation=$operation',
        error: error.runtimeType,
        trace: StackTrace.empty,
      );
    }
  }

  /// Turns a thrown datasource error into the right failure variant.
  ///
  /// Two signals have to survive this boundary as types:
  ///
  /// - an LWK status conflict, which requires writer-owned reconciliation.
  /// - an Electrum failure from a `sync: true` read, which is a *sync*
  ///   failure, not a read failure: the stored wallet is fine, only its
  ///   balance is stale, and the remedy is the server settings.
  WalletFailure _classify(Object e, String operation) {
    if (e is WalletFailure) return e;
    if (e is WalletSnapshotException) {
      if (e.failure is TransactionSyncBusyFailure) {
        return const WalletSyncFailure('reader busy');
      }
      return WalletStorageFailure('$operation: ${e.failure.runtimeType}');
    }
    if ((e is lwk.LwkError && e.msg.contains('UpdateOnDifferentStatus')) ||
        e.toString().contains('UpdateOnDifferentStatus')) {
      return WalletLwkStatusConflictFailure('$operation: lwk status conflict');
    }
    if (e is ElectrumFallbackException) {
      return WalletSyncFailure('$operation: ${e.runtimeType}');
    }
    return WalletStorageFailure('$operation failed: ${e.runtimeType}');
  }

  Future<List<Wallet>> _readWallets({
    Environment? environment,
    bool? onlyDefaults,
    bool? onlyBitcoin,
    bool? onlyLiquid,
    bool sync = false,
  }) async {
    final metadatas = await _walletMetadataDatasource.fetchAll();
    if (metadatas.isEmpty) return [];

    var invalid = 0;
    final wallets = await Future.wait(
      metadatas.map((metadata) async {
        try {
          final network = metadata.network;
          if ((environment != null &&
                  network.isMainnet != environment.isMainnet) ||
              (onlyDefaults == true && !metadata.isDefault) ||
              (onlyBitcoin == true && !network.isBitcoin) ||
              (onlyLiquid == true && !network.isLiquid)) {
            return null;
          }
          return _walletFromMetadata(
            metadata,
            await _readBalance(metadata, sync: sync),
          );
        } catch (error) {
          invalid++;
          return null;
        }
      }),
    );
    if (invalid != _invalidCatalogCount) {
      _invalidCatalogCount = invalid;
      log.warning('Wallet catalog read invalid_count=$invalid');
    }
    return wallets.whereType<Wallet>().toList();
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

  @useResult
  Future<Result<void, WalletFailure>> deleteWallet({
    required String walletId,
  }) async {
    try {
      final metadata = await _walletMetadataDatasource.fetch(walletId);
      if (metadata == null) {
        return const Err(WalletNotFoundFailure('no metadata to delete'));
      }

      final native = _native;
      if (native == null) throw StateError('Native writer is not configured');
      await native.delete(metadata);

      await _walletMetadataDatasource.delete(walletId);
      await native.catalogDeleted(metadata);
      return const Ok(null);
    } catch (e, st) {
      log.severe(message: 'deleteWallet failed', error: e, trace: st);
      return Err(_classify(e, 'deleteWallet'));
    }
  }

  Future<void> _updateWalletSyncTime(String walletId) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      return;
    }

    final updatedWalletMetadata = metadata.copyWith(syncedAt: DateTime.now());

    await _walletMetadataDatasource.store(updatedWalletMetadata);
  }

  Future<void> _provision(WalletMetadataModel metadata) async {
    if (await _walletMetadataDatasource.fetch(metadata.id) != null) {
      throw WalletAlreadyExistsException(metadata.id);
    }
    await _native?.prepareCreate(metadata);
    // The writer resolves descriptors from this row. Claim it exclusively,
    // without holding an app database transaction across native work.
    await _walletMetadataDatasource.insert(metadata);
    try {
      await _createNative(metadata);
    } catch (_) {
      // Only a successful insert owns compensation; a duplicate never deletes.
      // Keep secrets and native recovery state for a later retry.
      await _walletMetadataDatasource.delete(metadata.id);
      log.warning('Wallet creation failed catalog row removed');
      rethrow;
    }
  }

  Future<void> _createNative(WalletMetadataModel metadata) async {
    final native = _native;
    if (native == null) throw StateError('Native writer is not configured');
    await native.create(metadata);
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
        await _syncWallet(metadata);
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
        await _syncWallet(metadata);
      }

      balance = await _bdkWallet.getBalance(wallet: wallet);
    }

    return balance;
  }

  Future<void> sync(Wallet wallet, {bool discover = false}) async {
    await _syncWallet(
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
      discover: discover,
    );
  }

  Future<bool> isTorRequired() async {
    final defaultWallets = await _readWallets(
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
