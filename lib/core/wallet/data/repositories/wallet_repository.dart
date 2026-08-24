import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_metadata_mapper.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_signer_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_balances.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_signer_device_port.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:crypto/crypto.dart';

class WalletRepository
    implements BitcoinDescriptorPort, WalletSignerDevicePort {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final BdkWalletDatasource _bdkWallet;
  final LwkWalletDatasource _lwkWallet;
  final ElectrumServersPort _serversPort;

  final _electrumSyncResultController =
      StreamController<ElectrumSyncResult>.broadcast();

  WalletRepository({
    required this._walletMetadataDatasource,
    required BdkWalletDatasource bdkWalletDatasource,
    required LwkWalletDatasource lwkWalletDatasource,
    required this._serversPort,
  }) : _bdkWallet = bdkWalletDatasource,
       _lwkWallet = lwkWalletDatasource {
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

    var metadata = await WalletMetadataService.deriveFromSeed(
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

    if (network.isBitcoin) {
      final descriptor = _bdkWallet.parsePublicTwoPathDescriptor(
        descriptor: metadata.publicDescriptor,
        isTestnet: network.isTestnet,
      );
      try {
        await _ensureUniqueBitcoinDescriptor(
          metadata: metadata,
          scriptIdentity: descriptor.scriptIdentity,
        );
      } on WalletAlreadyExistsException catch (error) {
        final existing = await _walletMetadataDatasource.fetch(error.walletId);
        if (existing == null || existing.network != metadata.network) {
          rethrow;
        }
        final canReplaceSigners = existing.signers.every(
          (signer) =>
              signer.signer.toEntity() == SignerEntity.none ||
              (signer.signer.toEntity() == SignerEntity.remote &&
                  signer.signerDevice == null),
        );
        if ((!isDefault && !canReplaceSigners) ||
            (isDefault && existing.isDefault)) {
          rethrow;
        }
        metadata = existing.copyWith(
          signers: metadata.signers,
          publicDescriptor: metadata.publicDescriptor,
          isDefault: existing.isDefault || isDefault,
          label: isDefault ? metadata.label : existing.label,
          birthday: existing.birthday ?? metadata.birthday,
        );
      }
    }

    final balance = await _getBalance(metadata, sync: sync);
    await _walletMetadataDatasource.store(metadata);

    return _toWallet(metadata, balance);
  }

  @override
  ({
    String descriptor,
    ScriptType? scriptType,
    List<WalletDescriptorKey> descriptorKeys,
    bool inferredChangePath,
  })
  parseBitcoinDescriptor({
    required String descriptor,
    required Network network,
  }) {
    _requireBitcoinNetwork(network);
    final parsed = _bdkWallet.parsePublicTwoPathDescriptor(
      descriptor: descriptor,
      isTestnet: network.isTestnet,
    );
    return (
      descriptor: parsed.descriptor,
      scriptType: parsed.scriptType,
      descriptorKeys: _descriptorKeys(parsed.keys),
      inferredChangePath: parsed.inferredChangePath,
    );
  }

  @override
  ({List<WalletDescriptorKey> policyKeys, bool hasUnspendablePolicyKey})
  analyzeBitcoinPolicyDescriptor({
    required String descriptor,
    required Network network,
  }) {
    _requireBitcoinNetwork(network);
    final parsed = _bdkWallet.parsePublicTwoPathDescriptor(
      descriptor: descriptor,
      isTestnet: network.isTestnet,
    );
    return (
      policyKeys: _descriptorKeys(parsed.policyKeys),
      hasUnspendablePolicyKey:
          parsed.unspendablePolicyKeyIdentifiers.isNotEmpty,
    );
  }

  @override
  Future<Wallet> importDescriptor({
    required String descriptor,
    required Network network,
    required String label,
    List<WalletSigner> signers = const [],
    bool sync = false,
  }) async {
    _requireBitcoinNetwork(network);
    final parsed = _bdkWallet.parsePublicTwoPathDescriptor(
      descriptor: descriptor,
      isTestnet: network.isTestnet,
    );
    final parsedKeys = _descriptorKeys(parsed.keys);
    final metadata = WalletMetadataModel(
      id: sha256
          .convert(utf8.encode('${network.name}:${parsed.scriptIdentity}'))
          .toString(),
      network: network,
      signers: _applySignerAnnotations(
        parsedKeys,
        annotations: signers,
      ).map((signer) => signer.toModel()).toList(),
      publicDescriptor: parsed.descriptor,
      isDefault: false,
      isEncryptedVaultTested: false,
      isPhysicalBackupTested: false,
      label: label,
    );

    await _ensureUniqueBitcoinDescriptor(
      metadata: metadata,
      scriptIdentity: parsed.scriptIdentity,
    );

    final balance = await _getBalance(metadata, sync: sync);
    await _walletMetadataDatasource.store(metadata);

    return _toWallet(metadata, balance);
  }

  Future<void> _ensureUniqueBitcoinDescriptor({
    required WalletMetadataModel metadata,
    required String scriptIdentity,
  }) async {
    final existingWallets = await _walletMetadataDatasource.fetchAll();
    for (final existing in existingWallets) {
      if (existing.id == metadata.id ||
          existing.publicDescriptor == metadata.publicDescriptor) {
        throw WalletAlreadyExistsException(existing.id);
      }
      if (existing.network != metadata.network || !existing.network.isBitcoin) {
        continue;
      }

      try {
        final existingDescriptor = _bdkWallet.parsePublicTwoPathDescriptor(
          descriptor: existing.publicDescriptor,
          isTestnet: metadata.network.isTestnet,
        );
        if (existingDescriptor.scriptIdentity == scriptIdentity) {
          throw WalletAlreadyExistsException(existing.id);
        }
      } on WalletAlreadyExistsException {
        rethrow;
      } on Exception {
        // Exact descriptor and ID checks above still protect stored wallet
        // forms that are not supported by the Bitcoin descriptor parser.
      }
    }
  }

  void _requireBitcoinNetwork(Network network) {
    if (!network.isBitcoin) {
      throw ArgumentError.value(
        network,
        'network',
        'must be a Bitcoin network',
      );
    }
  }

  Future<Wallet?> getWallet(String walletId, {bool sync = false}) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      return null;
    }
    // Get the balance
    final balance = await _getBalance(metadata, sync: sync);

    return _toWallet(metadata, balance);
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

    return [
      for (final (index, metadata) in filteredWallets.indexed)
        _toWallet(metadata, balances[index]),
    ];
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

  @override
  Future<Wallet> updateSignerDevice({
    required String walletId,
    required String signerId,
    required SignerDeviceEntity? signerDevice,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) throw const WalletSignerDeviceUpdateException();

    final signerIndex = metadata.signers.indexWhere(
      (signer) => signer.id == signerId,
    );
    if (signerIndex == -1) {
      throw const WalletSignerDeviceUpdateException();
    }

    final signer = metadata.signers[signerIndex].toEntity();
    if (signer.signer == SignerEntity.local) {
      throw const WalletSignerDeviceUpdateException();
    }

    final updatedSigner = signer
        .copyWith(
          signer: SignerEntity.remote,
          signerDevice: signerDevice,
          clearSignerDevice: signerDevice == null,
        )
        .toModel();
    final updatedSigners = [...metadata.signers];
    updatedSigners[signerIndex] = updatedSigner;
    final updatedMetadata = metadata.copyWith(signers: updatedSigners);
    final balance = await _getBalance(updatedMetadata);
    final didUpdate = await _walletMetadataDatasource.updateSignerDevice(
      walletId: walletId,
      signerId: signerId,
      signer: updatedSigner.signer,
      signerDevice: updatedSigner.signerDevice,
    );
    if (!didUpdate) throw const WalletSignerDeviceUpdateException();
    return _toWallet(updatedMetadata, balance);
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
      try {
        await _bdkWallet.delete(wallet: WalletModel.fromMetadata(metadata));
      } on WalletNotFound {
        log.warning('deleteWallet: BDK file already absent for $walletId');
      }
    }

    if (metadata.isLiquid) {
      try {
        await _lwkWallet.delete(wallet: WalletModel.fromMetadata(metadata));
      } on WalletNotFound {
        log.warning('deleteWallet: LWK file already absent for $walletId');
      }
    }

    await _walletMetadataDatasource.delete(walletId);
  }

  // used only to delete lwk db - required for UpdateOnDifferentStatusError
  Future<void> deleteLwkDb() async {
    final metadatas = await _walletMetadataDatasource.fetchAll();

    final liquidDefaultWallets = metadatas.where(
      (metadata) => metadata.isDefault && metadata.isLiquid,
    );

    for (final metadata in liquidDefaultWallets) {
      try {
        await _lwkWallet.delete(wallet: WalletModel.fromMetadata(metadata));
      } on WalletNotFound {
        log.warning('deleteLwkDb: LWK file already absent for ${metadata.id}');
      }
    }
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
    await _walletMetadataDatasource.updateSyncedAt(
      walletId: walletId,
      syncedAt: DateTime.now(),
    );
  }

  Future<BalanceModel> _getBalance(
    WalletMetadataModel metadata, {
    bool sync = false,
  }) async {
    BalanceModel balance;
    if (metadata.isLiquid) {
      final wallet = WalletModel.publicLwk(
        combinedCtDescriptor: metadata.publicDescriptor,
        isTestnet: metadata.isTestnet,
        id: metadata.id,
      );

      if (sync) {
        await _syncWallet(wallet);
      }

      balance = await _lwkWallet.getBalance(wallet: wallet);
    } else {
      final wallet = WalletModel.publicBdk(
        descriptor: metadata.publicDescriptor,
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
        network: wallet.network,
        signers: wallet.signers.map((signer) => signer.toModel()).toList(),
        isEncryptedVaultTested: wallet.isEncryptedVaultTested,
        isPhysicalBackupTested: wallet.isPhysicalBackupTested,
        publicDescriptor: wallet.publicDescriptor,
        isDefault: wallet.isDefault,
        label: wallet.label,
      ),
    );
    await _syncWallet(walletModel);
  }

  Wallet _toWallet(
    WalletMetadataModel metadata,
    BalanceModel balance,
  ) => Wallet(
    origin: metadata.id,
    label: metadata.label,
    network: metadata.network,
    isDefault: metadata.isDefault,
    signers: metadata.signers.map((signer) => signer.toEntity()).toList(),
    scriptType: metadata.inferredScriptType,
    publicDescriptor: metadata.publicDescriptor,
    balanceSat: balance.totalSat,
    confirmedBalanceSat: balance.confirmedSat,
    isEncryptedVaultTested: metadata.isEncryptedVaultTested,
    isPhysicalBackupTested: metadata.isPhysicalBackupTested,
    latestEncryptedBackup: metadata.latestEncryptedBackup != null
        ? DateTime.fromMillisecondsSinceEpoch(metadata.latestEncryptedBackup!)
        : null,
    latestPhysicalBackup: metadata.latestPhysicalBackup != null
        ? DateTime.fromMillisecondsSinceEpoch(metadata.latestPhysicalBackup!)
        : null,
  );

  Future<void> _syncWallet(WalletModel wallet) async {
    final isLiquid = wallet is PublicLwkWalletModel;
    final network = ElectrumServerNetwork.fromEnvironment(
      isTestnet: wallet.isTestnet,
      isLiquid: isLiquid,
    );

    try {
      await _serversPort.runWithFallback<void>(
        network: network,
        operation: (connection) async {
          if (isLiquid) {
            await _lwkWallet.sync(wallet: wallet, electrumServer: connection);
          } else {
            await _bdkWallet.sync(wallet: wallet, electrumServer: connection);
          }
        },
      );
      _electrumSyncResultController.add(
        ElectrumSyncResult(isLiquid: isLiquid, success: true),
      );
    } on ElectrumFallbackException catch (e, stackTrace) {
      // Both NoElectrumServersConfigured and AllElectrumServersFailed land
      // here. Emit the failed result, log the rich `e.message` (per-server
      // attempts on failure, network on no-config), then rethrow the typed
      // exception so callers keep the diagnostic instead of receiving a
      // flat string they have to parse.
      log.severe(message: e.message, error: e, trace: stackTrace);
      _electrumSyncResultController.add(
        ElectrumSyncResult(isLiquid: isLiquid, success: false),
      );
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
        combinedCtDescriptor: metadata.publicDescriptor,
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

  static List<WalletDescriptorKey> _descriptorKeys(
    List<BdkDescriptorKey> keys,
  ) => [
    for (final (index, key) in keys.indexed)
      WalletDescriptorKey(
        id: 'key-$index',
        signerId: 'signer-$index',
        masterFingerprint: key.masterFingerprint,
        xpubFingerprint: key.xpubFingerprint,
        xpub: key.xpub,
        derivationPath: key.derivationPath,
        descriptorPath: key.descriptorPath,
      ),
  ];

  static List<WalletSigner> _applySignerAnnotations(
    List<WalletDescriptorKey> keys, {
    required List<WalletSigner> annotations,
  }) {
    final annotationsByKey = {
      for (final signer in annotations)
        for (final key in signer.descriptorKeys) key.id: signer,
    };
    final annotationsById = {
      for (final signer in annotations) signer.id: signer,
    };
    final grouped = <String, List<WalletDescriptorKey>>{};
    for (final key in keys) {
      final annotation = annotationsByKey[key.id];
      final signerId = annotation?.id ?? key.signerId;
      grouped
          .putIfAbsent(signerId, () => [])
          .add(key.copyWith(signerId: signerId));
    }
    return [
      for (final entry in grouped.entries)
        WalletSigner(
          id: entry.key,
          signer: annotationsById[entry.key]?.signer ?? SignerEntity.none,
          signerDevice: annotationsById[entry.key]?.signerDevice,
          descriptorKeys: entry.value,
        ),
    ];
  }
}
