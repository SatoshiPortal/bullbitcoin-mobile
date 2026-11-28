import 'package:bb_mobile/features/wallet/data/wallet_sync_binding.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_reader_repository.dart';
import 'package:sync/diagnostics.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure_log_code.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/features/wallet/data/wallet_network_codec.dart';

import 'dart:async';

import 'package:sync/write.dart' show ForegroundWalletSynchronization;
import 'package:sync/sync.dart' show WalletSnapshotException;
import 'package:sync/sync.dart'
    show
        SyncReason,
        SyncStorageFailure,
        SyncInvalidCatalogFailure,
        isLiquidStatusConflict;

import 'package:electrum/setup.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:sync/storage.dart' show SyncWalletValuesDatasource;
import 'package:sync/sync.dart' as native_sync;
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';

class WalletRepository implements WalletReaderRepository {
  final _unavailable = <String, Type>{};
  int _invalidCatalogCount = 0;
  final WalletRegistrations _walletRegistrations;
  final WalletSessionJoin _session;
  final SyncWalletValuesDatasource _values;
  final ForegroundWalletSynchronization _synchronization;
  final Stream<String> _walletSyncStartedStream;
  final Stream<String> _walletSyncFinishedStream;

  WalletRepository({
    required this._walletRegistrations,
    required this._session,
    required SyncWalletValuesDatasource walletValuesDatasource,
    required this._synchronization,
    required Stream<String> syncStarted,
    required Stream<String> syncFinished,
  }) : _values = walletValuesDatasource,
       _walletSyncStartedStream = syncStarted,
       _walletSyncFinishedStream = syncFinished;

  Stream<String> get walletSyncStartedStream => _walletSyncStartedStream;

  Stream<Wallet> get walletSyncFinishedStream => _walletSyncFinishedStream
      .asyncMap<Result<Wallet, WalletFailure>>((id) => getWallet(id))
      .map<Wallet?>((result) => result.fold((w) => w, (_) => null))
      .where((wallet) => wallet != null)
      .map((wallet) => wallet!);

  @override
  @useResult
  Future<Result<Wallet, WalletFailure>> getWallet(
    String walletId, {
    bool sync = false,
  }) async {
    try {
      final wallet = await _session(() => _readWallet(walletId, sync: sync));
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
    final metadata = await _walletRegistrations.fetch(walletId);

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

  Future<native_sync.Balances?> _readBalance(
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
    native_sync.Balances? balance,
  ) {
    final encrypted = metadata.latestEncryptedBackup;
    final physical = metadata.latestPhysicalBackup;
    // Return the wallet entity
    return Wallet(
      origin: metadata.origin,
      label: metadata.label,
      network: metadata.network,
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
        walletDisplayOrder(
          await LeaseDiagnostics.from(
            LeaseSource.walletList,
            () => _session(
              () => _readWallets(
                environment: environment,
                onlyDefaults: onlyDefaults,
                onlyBitcoin: onlyBitcoin,
                onlyLiquid: onlyLiquid,
                sync: sync,
              ),
            ),
          ),
        ),
      );
    } catch (e, st) {
      _reportReadFailure(e, st, 'getWallets');
      return Err(_classify(e, 'getWallets'));
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
    bool sync = false,
  }) async {
    final metadatas = await _walletRegistrations.fetchAll();
    if (metadatas.isEmpty) return [];

    var invalid = 0;
    final wallets = await Future.wait(
      metadatas.map((metadata) async {
        try {
          final network = metadata.network;
          if ((environment != null &&
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

  Future<native_sync.Balances> getWalletBalances({
    required String walletId,
  }) async {
    return _session(() async {
      final metadata = await _walletRegistrations.fetch(walletId);
      if (metadata == null) {
        throw WalletNotFoundException(walletId);
      }
      return _getBalance(metadata);
    });
  }

  /// Synchronizes the native wallet [metadata] describes.
  Future<void> _syncWallet(
    WalletMetadataModel metadata, {
    bool discover = false,
    bool allowInitialScan = true,
    SyncReason reason = SyncReason.auto,
  }) async {
    switch (WalletSyncBinding.descriptorFromMetadata(metadata)) {
      case Err():
        throw const WalletStorageFailure('Invalid sync descriptor');
      case Ok(:final value):
        WalletSyncBinding.value(
          await _synchronization.execute(
            value,
            discover: discover,
            allowInitialScan: allowInitialScan,
            reason: reason,
          ),
        );
    }
  }

  Future<native_sync.Balances> _getBalance(
    WalletMetadataModel metadata, {
    bool sync = false,
  }) async {
    final key = native_sync.WalletKey(
      id: metadata.id,
      network: metadata.network.shared,
    );
    if (sync) {
      await _syncWallet(metadata);
    }
    return _values.getBalance(key: key);
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
        masterFingerprint: wallet.masterFingerprint,
        xpubFingerprint: wallet.xpubFingerprint,
        isEncryptedVaultTested: wallet.isEncryptedVaultTested,
        isPhysicalBackupTested: wallet.isPhysicalBackupTested,
        externalPublicDescriptor: wallet.externalPublicDescriptor,
        internalPublicDescriptor: wallet.internalPublicDescriptor,
        xpub: wallet.xpub,
        isDefault: wallet.isDefault,
        label: wallet.label,
        signer: wallet.signer.toSqlite(),
      ),
      discover: discover,
      allowInitialScan: allowInitialScan,
      reason: reason,
    );
  }
}

/// The default Bitcoin and Liquid wallets precede imports, whose order is stable.
List<Wallet> walletDisplayOrder(Iterable<Wallet> wallets) {
  int rank(Wallet wallet) => switch (wallet) {
    _ when wallet.isDefault && !wallet.isLiquid => 0,
    _ when wallet.isDefault && wallet.isLiquid => 1,
    _ => 2,
  };
  final indexed = wallets.toList().indexed.toList()
    ..sort((a, b) {
      final byRank = rank(a.$2).compareTo(rank(b.$2));
      return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
    });
  return [for (final (_, wallet) in indexed) wallet];
}
