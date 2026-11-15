import 'package:bb_mobile/core/wallet/domain/wallet_signer_ownership_port.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_visibility_port.dart';
import 'package:bb_mobile/core/utils/bip48_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/bip48_account_usage_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bip48_account_usage.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_signer_device_port.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/features/wallet/data/bitcoin_descriptor_codec.dart'
    show BdkDescriptorKey;
import 'package:bb_mobile/core/wallet/data/mappers/wallet_metadata_mapper.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_signer_mapper.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_reader_repository.dart';
import 'package:sync/diagnostics.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure_log_code.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok, Result;
import 'package:bb_mobile/features/wallet/data/wallet_network_codec.dart';

import 'dart:async';

import 'package:bb_mobile/features/wallet/data/wallet_native_runtime.dart';
import 'package:sync/sync.dart' show WalletSnapshotException;
import 'package:sync/sync.dart'
    show
        SyncReason,
        SyncStorageFailure,
        SyncInvalidCatalogFailure,
        isLiquidStatusConflict;

import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/wallet/data/bdk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';
import 'package:bb_mobile/features/wallet/data/lwk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_balances.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_service.dart';
import 'package:meta/meta.dart';

class WalletRepository
    implements
        SeedReferencePort,
        WalletReaderRepository,
        BitcoinDescriptorPort,
        WalletSignerDevicePort,
        WalletSignerOwnershipPort,
        WalletVisibilityPort,
        Bip48AccountUsagePort {
  final WalletNativeLifecycle? _native;
  final _unavailable = <String, Type>{};
  int _invalidCatalogCount = 0;
  final WalletMetadataDatasource _walletMetadataDatasource;
  final BdkWalletDatasource _bdkWallet;
  final LwkWalletDatasource _lwkWallet;
  final SyncWalletValuesDatasource _values;
  final Future<void> Function(
    WalletMetadataModel, {
    bool discover,
    bool allowInitialScan,
    SyncReason reason,
  })
  _syncWallet;
  final bool Function({String? walletId}) _isSyncing;
  final Stream<String> _walletSyncStartedStream;
  final Stream<String> _walletSyncFinishedStream;
  final Stream<ElectrumSyncResult> electrumSyncResultStream;

  WalletRepository({
    this._native,
    required this._walletMetadataDatasource,
    required BdkWalletDatasource bdkWalletDatasource,
    required LwkWalletDatasource lwkWalletDatasource,
    required SyncWalletValuesDatasource walletValuesDatasource,
    required Future<void> Function(
      WalletMetadataModel, {
      bool discover,
      bool allowInitialScan,
      SyncReason reason,
    })
    synchronize,
    required this._isSyncing,
    required Stream<String> syncStarted,
    required Stream<String> syncFinished,
    required this.electrumSyncResultStream,
  }) : _bdkWallet = bdkWalletDatasource,
       _lwkWallet = lwkWalletDatasource,
       _values = walletValuesDatasource,
       _syncWallet = synchronize,
       _walletSyncStartedStream = syncStarted,
       _walletSyncFinishedStream = syncFinished {
    // Keep track of the last sync time in the wallet metadata
    _walletSyncFinishedStream.listen(_updateWalletSyncTime);
    // Start auto syncing wallets
  }

  Stream<String> get walletSyncStartedStream => _walletSyncStartedStream;

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

  /// Catalog existence protects onboarding even when the selected network
  /// has no wallets or a stored network cannot currently be decoded.
  @useResult
  Future<Result<bool, WalletFailure>> hasStoredWallets() async {
    try {
      return Ok((await _walletMetadataDatasource.fetchAll()).isNotEmpty);
    } catch (error) {
      return Err(_classify(error, 'hasStoredWallets'));
    }
  }

  /// Reads every catalog row, including unresolved networks and unavailable
  /// native stores: neither condition permits deleting a shared secret.
  @useResult
  Future<Result<bool, WalletFailure>> hasSecretReference(
    Fingerprint fingerprint,
  ) async {
    try {
      final rows = await _walletMetadataDatasource.fetchAll();
      return Ok(
        rows.any(
          (row) => row.signers
              .where((signer) => signer.signer == Signer.local)
              .any(
                (signer) => signer.descriptorKeys.any(
                  (key) =>
                      Fingerprint.tryParse(key.masterFingerprint) ==
                      fingerprint,
                ),
              ),
        ),
      );
    } catch (error) {
      return Err(_classify(error, 'hasSecretReference'));
    }
  }

  @override
  Future<List<Bip48AccountUsage>> getBip48AccountUsages() async {
    final wallets = await _walletMetadataDatasource.fetchAll();
    return [
      for (final wallet in wallets)
        if (wallet.network.isBitcoin)
          for (final signer in wallet.signers)
            for (final key in signer.descriptorKeys)
              if (key.derivationPath case final path?)
                if (Bip48Derivation.account(
                      path,
                      coinType: wallet.network.coinType,
                    )
                    case final account?)
                  Bip48AccountUsage(
                    seedFingerprint: key.masterFingerprint.toLowerCase(),
                    localSeedFingerprint: signer.localSeedFingerprint,
                    coinType: wallet.network.coinType,
                    account: account,
                    derivationPath: path,
                    xpub: key.xpub,
                  ),
    ];
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

    var upgradingExisting = false;
    var metadata = await WalletMetadataService.deriveFromSecret(
      secret: secret,
      network: network,
      scriptType: scriptType,
      label: walletLabel,
      isDefault: isDefault,
      birthday: birthday,
    );

    if (isDefault) {
      final allWallets = await _readWallets(onlyDefaults: true);
      for (final wallet in allWallets) {
        if (wallet.isDefault && wallet.network == metadata.network) {
          throw Exception('Default wallet already exists');
        }
      }
    }

    if (network.isBitcoin) {
      final descriptor = _bdkWallet.parsePublicTwoPathDescriptor(
        descriptor: metadata.publicDescriptor,
        network: network,
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
        upgradingExisting = true;
        metadata = existing.copyWith(
          signers: metadata.signers,
          publicDescriptor: metadata.publicDescriptor,
          isDefault: existing.isDefault || isDefault,
          label: isDefault ? metadata.label : existing.label,
          birthday: existing.birthday ?? metadata.birthday,
        );
      }
    }

    if (upgradingExisting) {
      await _walletMetadataDatasource.store(metadata);
    } else {
      await _provision(metadata);
    }
    return _walletFromMetadata(
      metadata,
      await _getBalance(metadata, sync: sync),
    );
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
      network: network,
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
      network: network,
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
    bool isHidden = false,
    bool sync = false,
  }) async {
    _requireBitcoinNetwork(network);
    final parsed = _bdkWallet.parsePublicTwoPathDescriptor(
      descriptor: descriptor,
      network: network,
    );
    final parsedKeys = _descriptorKeys(parsed.keys);
    final metadata = WalletMetadataModel(
      id:
          sha256
              .convert(utf8.encode('${network.name}:${parsed.scriptIdentity}'))
              .toString() +
          (network == Network.bitcoinRegtest
              ? WalletMetadataService.regtestSuffix
              : ''),
      networkCode: WalletNetworkCodec.encode(network),
      signers: _applySignerAnnotations(
        parsedKeys,
        annotations: signers,
      ).map((signer) => signer.toModel()).toList(),
      publicDescriptor: parsed.descriptor,
      isDefault: false,
      isHidden: isHidden,
      isEncryptedVaultTested: false,
      isPhysicalBackupTested: false,
      label: label,
    );

    await _ensureUniqueBitcoinDescriptor(
      metadata: metadata,
      scriptIdentity: parsed.scriptIdentity,
    );

    await _provision(metadata);
    return _walletFromMetadata(
      metadata,
      await _readBalance(metadata, sync: sync),
    );
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
      if (existing.networkCode != metadata.networkCode ||
          !metadata.network.isBitcoin) {
        continue;
      }

      try {
        final existingDescriptor = _bdkWallet.parsePublicTwoPathDescriptor(
          descriptor: existing.publicDescriptor,
          network: metadata.network,
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

  @override
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
        log.warning(
          'Wallet balance unavailable category=${_classify(error, 'balance').logCode}',
        );
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
      origin: WalletMetadataService.originFromId(metadata.id),
      label: metadata.label,
      network: metadata.network,
      isDefault: metadata.isDefault,
      isHidden: metadata.isHidden,
      signers: metadata.signers.map((signer) => signer.toEntity()).toList(),
      scriptType: metadata.inferredScriptType,
      publicDescriptor: metadata.publicDescriptor,
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
    bool includeHidden = false,
    bool sync = false,
  }) async {
    try {
      return Ok(
        await LeaseDiagnostics.from(
          LeaseSource.walletList,
          () => _readWallets(
            environment: environment,
            onlyDefaults: onlyDefaults,
            onlyBitcoin: onlyBitcoin,
            onlyLiquid: onlyLiquid,
            includeHidden: includeHidden,
            sync: sync,
          ),
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
        for (final signer in row.signers.where(
          (signer) => signer.signer == Signer.local,
        )) {
          for (final reference in switch (signer.localSeedFingerprint) {
            final fingerprint? => <String>[fingerprint],
            null => signer.descriptorKeys.map((key) => key.masterFingerprint),
          }) {
            final fingerprint = Fingerprint.tryParse(reference);
            if (fingerprint == null) {
              return const Err(
                WalletStorageFailure('invalid custody reference'),
              );
            }
            fingerprints.add(fingerprint);
          }
        }
      }
      return Ok(fingerprints);
    } catch (_) {
      log.warning('Wallet custody references unavailable category=storage');
      return const Err(WalletStorageFailure('custody references unavailable'));
    }
  }

  void _reportReadFailure(Object error, StackTrace trace, String operation) {
    // Native readers and sync already own their terminal diagnostics.
    if (error is WalletSnapshotException) return;
    if (error is WalletSyncFailure) {
      log.warning(
        'Wallet sync unavailable operation=$operation reason=connection',
      );
    } else {
      log.severe(
        message: 'Wallet read failed operation=$operation reason=storage',
        error: 'storage',
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
      return switch (e.failure) {
        SyncStorageFailure() || SyncInvalidCatalogFailure() =>
          WalletStorageFailure('$operation: ${e.failure.logCode}'),
        _ => WalletSyncFailure('$operation: ${e.failure.logCode}'),
      };
    }
    if (isLiquidStatusConflict(e) ||
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
    bool includeHidden = false,
    bool sync = false,
  }) async {
    final metadatas = await _walletMetadataDatasource.fetchAll();
    if (metadatas.isEmpty) return [];

    var invalid = 0;
    final wallets = await Future.wait(
      metadatas.map((metadata) async {
        try {
          final network = metadata.network;
          if ((!includeHidden && metadata.isHidden) ||
              (environment != null &&
                  network.environment != environment.networkEnv) ||
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

  @override
  Future<void> setHidden({
    required String walletId,
    required bool isHidden,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) throw WalletError.notFound(walletId);
    await _walletMetadataDatasource.store(
      metadata.copyWith(isHidden: isHidden),
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
    return _walletFromMetadata(updatedMetadata, balance);
  }

  @override
  Future<Wallet> updateSignerRegistrationName({
    required String walletId,
    required String signerId,
    required String registrationName,
  }) async {
    final normalizedName = registrationName.trim();
    if (normalizedName.isEmpty) {
      throw const WalletSignerDeviceUpdateException();
    }
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) throw const WalletSignerDeviceUpdateException();
    final signerIndex = metadata.signers.indexWhere(
      (signer) => signer.id == signerId,
    );
    if (signerIndex == -1) {
      throw const WalletSignerDeviceUpdateException();
    }
    final updatedSigner = metadata.signers[signerIndex]
        .toEntity()
        .copyWith(registrationName: normalizedName)
        .toModel();
    final updatedSigners = [...metadata.signers];
    updatedSigners[signerIndex] = updatedSigner;
    final updatedMetadata = metadata.copyWith(signers: updatedSigners);
    final didUpdate = await _walletMetadataDatasource
        .updateSignerRegistrationName(
          walletId: walletId,
          signerId: signerId,
          registrationName: normalizedName,
        );
    if (!didUpdate) throw const WalletSignerDeviceUpdateException();
    return _walletFromMetadata(
      updatedMetadata,
      await _getBalance(updatedMetadata),
    );
  }

  @override
  Future<Wallet> markSignerLocal({
    required String walletId,
    required String signerId,
    required String seedFingerprint,
    required Set<String> passphraseProtectedKeyIds,
  }) async {
    if (seedFingerprint.trim().isEmpty) {
      throw const WalletSignerOwnershipUpdateException();
    }
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw const WalletSignerOwnershipUpdateException();
    }
    final signerIndex = metadata.signers.indexWhere(
      (signer) => signer.id == signerId,
    );
    if (signerIndex == -1) {
      throw const WalletSignerOwnershipUpdateException();
    }
    final existing = metadata.signers[signerIndex].toEntity();
    final keyIds = existing.descriptorKeys.map((key) => key.id).toSet();
    if (!keyIds.containsAll(passphraseProtectedKeyIds)) {
      throw const WalletSignerOwnershipUpdateException();
    }
    final updatedSigner = WalletSigner(
      id: existing.id,
      signer: SignerEntity.local,
      signerDevice: null,
      localSeedFingerprint: seedFingerprint.toLowerCase(),
      descriptorKeys: [
        for (final key in existing.descriptorKeys)
          key.copyWith(
            requiresPassphrase: passphraseProtectedKeyIds.contains(key.id),
          ),
      ],
    ).toModel();
    final updatedSigners = [...metadata.signers];
    updatedSigners[signerIndex] = updatedSigner;
    final updatedMetadata = metadata.copyWith(signers: updatedSigners);
    await _walletMetadataDatasource.store(updatedMetadata);
    return _walletFromMetadata(
      updatedMetadata,
      await _getBalance(updatedMetadata),
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
      log.fine('Wallet deleted outcome=ok');
      return const Ok(null);
    } catch (e, st) {
      if (e is! WalletSnapshotException) {
        log.severe(
          message: 'Wallet delete failed reason=storage',
          error: 'storage',
          trace: st,
        );
      }
      return Err(_classify(e, 'deleteWallet'));
    }
  }

  Future<void> _updateWalletSyncTime(String walletId) async {
    await _walletMetadataDatasource.updateSyncedAt(
      walletId: walletId,
      syncedAt: DateTime.now(),
    );
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
        combinedCtDescriptor: metadata.publicDescriptor,
        network: metadata.network,
        id: metadata.id,
      );

      if (sync) {
        await _syncWallet(metadata);
      }

      balance = await _values.getBalance(wallet: wallet);
    } else {
      final wallet = WalletModel.publicBdk(
        descriptor: metadata.publicDescriptor,
        network: metadata.network,
        id: metadata.id,
      );

      if (sync) {
        await _syncWallet(metadata);
      }

      balance = await _values.getBalance(wallet: wallet);
    }

    return balance;
  }

  Future<void> sync(
    Wallet wallet, {
    bool discover = false,
    bool allowInitialScan = true,
    SyncReason reason = SyncReason.auto,
  }) async {
    await _syncWallet(
      WalletMetadataModel(
        id: wallet.id,
        networkCode: WalletNetworkCodec.encode(wallet.network),
        signers: wallet.signers.map((signer) => signer.toModel()).toList(),
        isEncryptedVaultTested: wallet.isEncryptedVaultTested,
        isPhysicalBackupTested: wallet.isPhysicalBackupTested,
        publicDescriptor: wallet.publicDescriptor,
        isDefault: wallet.isDefault,
        label: wallet.label,
      ),
      discover: discover,
      allowInitialScan: allowInitialScan,
      reason: reason,
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
        combinedCtDescriptor: metadata.publicDescriptor,
        network: metadata.network,
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
        network: metadata.network,
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
        for (final key in signer.descriptorKeys)
          key.id: (signer: signer, key: key),
    };
    final annotationsById = {
      for (final signer in annotations) signer.id: signer,
    };
    final grouped = <String, List<WalletDescriptorKey>>{};
    for (final key in keys) {
      final annotation = annotationsByKey[key.id];
      final signerId = annotation?.signer.id ?? key.signerId;
      grouped
          .putIfAbsent(signerId, () => [])
          .add(
            key.copyWith(
              signerId: signerId,
              requiresPassphrase: annotation?.key.requiresPassphrase,
              derivationPath:
                  key.derivationPath ?? annotation?.key.derivationPath,
              masterFingerprint: key.masterFingerprint.isEmpty
                  ? annotation?.key.masterFingerprint
                  : key.masterFingerprint,
            ),
          );
    }
    return [
      for (final entry in grouped.entries)
        WalletSigner(
          id: entry.key,
          signer: annotationsById[entry.key]?.signer ?? SignerEntity.none,
          signerDevice: annotationsById[entry.key]?.signerDevice,
          registrationName: annotationsById[entry.key]?.registrationName,
          localSeedFingerprint:
              annotationsById[entry.key]?.localSeedFingerprint,
          descriptorKeys: entry.value,
        ),
    ];
  }
}
