import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import 'package:transaction_sync/transaction_sync.dart';

import '../domain/wallet_storage_paths.dart';
import 'bdk/bdk_wallet_transaction_source.dart';
import 'lwk/lwk_wallet_transaction_source.dart';
import '../domain/wallet_metadata.dart';

/// Publishes local history while the caller retains its native source session.
/// The caller may synchronize first; this capability never accesses the network.
class WalletSnapshotReader {
  final WalletStoragePathsPort _paths;
  final WalletSyncMetadataPort _metadata;
  final WalletTransactionSourcePort _bitcoin;
  final WalletTransactionSourcePort _liquid;

  WalletSnapshotReader({required this._paths, required this._metadata})
    : _bitcoin = BdkWalletTransactionSource(initializeLocal: true),
      _liquid = LwkWalletTransactionSource(initializeLocal: true);

  @useResult
  Future<Result<WalletTransactionSnapshot, WalletTransactionSyncFailure>> read({
    required WalletMetadata wallet,
    required WalletSourceSession session,
  }) async {
    session.ensureOpen();
    final paths = await _paths.resolve(wallet.id);
    final liquid = wallet.isLiquid;
    final key = WalletNetworkKey(
      wallet.id,
      liquid ? 'liquid' : 'bitcoin',
      wallet.isTestnet ? 'testnet' : 'mainnet',
    );
    final configuration = !liquid
        ? BdkElectrumConfiguration(
            externalPublicDescriptor: wallet.externalPublicDescriptor,
            internalPublicDescriptor: wallet.internalPublicDescriptor,
            isTestnet: wallet.isTestnet,
            electrumUrls: const [],
            stopGap: 25,
            validateDomain: true,
            databaseFilePath: paths.bdkDatabase,
          )
        : LwkElectrumConfiguration(
            confidentialPublicDescriptor: wallet.externalPublicDescriptor,
            isTestnet: wallet.isTestnet,
            electrumUrls: const [],
            validateDomain: true,
            databaseRootPath: paths.lwkRoot,
          );
    final registration = WalletSourceRegistration.withFingerprint(
      key: key,
      sourceKind: liquid ? 'lwk_electrum' : 'bdk_electrum',
      configuration: configuration,
    );
    final facade = WalletTransactionSyncFacade(
      source: liquid ? _liquid : _bitcoin,
      metadata: _LocalHistoryMetadata(registration, _metadata),
      coordinator: _BorrowedSourceSession(key, session),
    );
    try {
      final result = await facade.refreshLocalSnapshot(
        RefreshLocalSnapshotRequest(registration),
      );
      return result.map((value) => value.snapshot);
    } finally {
      await facade.dispose();
    }
  }
}

/// Does not acquire or release a lock: its owner encloses the whole read.
final class _BorrowedSourceSession implements WalletSourceOperationCoordinator {
  final WalletNetworkKey _key;
  final WalletSourceSession _session;

  const _BorrowedSourceSession(this._key, this._session);

  @override
  Future<T> runExclusive<T>(
    WalletSourceKey key,
    Future<T> Function(WalletSourceSession session) operation, {
    Duration? timeout = const Duration(seconds: 30),
    bool allowRetired = false,
    WalletOperationKind kind = WalletOperationKind.refresh,
    WalletOperationPriority priority = WalletOperationPriority.foreground,
  }) {
    _session.ensureOpen();
    if (key.walletId != _key.walletId ||
        key.chain != _key.chain ||
        key.network != _key.network ||
        kind != WalletOperationKind.refresh ||
        allowRetired) {
      throw StateError('Borrowed session permits only its local wallet read');
    }
    return operation(_session);
  }
}

/// Native history does not depend on the optional freshness database. A local
/// read neither registers a source nor resumes background deletion workflows;
/// the outer source coordinator remains the authority for retirement.
final class _LocalHistoryMetadata implements WalletSyncMetadataPort {
  final WalletSourceRegistration _registration;
  final WalletSyncMetadataPort _durable;

  const _LocalHistoryMetadata(this._registration, this._durable);

  @override
  Future<WalletSyncMetadata?> read(WalletNetworkKey key) async =>
      WalletSyncMetadata(registration: _registration);

  @override
  Future<WalletSyncReceipt?> readReceipt(WalletNetworkKey key) async {
    try {
      return await _durable.readReceipt(key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DateTime?> readLastSuccessfulSyncAt(WalletNetworkKey key) async =>
      (await readReceipt(key))?.successfulAt;

  @override
  Future<void> writeRegistration(WalletSourceRegistration registration) async =>
      _readOnly();
  @override
  Future<void> writeAttempt(WalletNetworkKey key, DateTime at) async =>
      _readOnly();
  @override
  Future<void> recordLegacyForegroundSuccess(
    WalletNetworkKey key,
    DateTime at,
  ) async => _readOnly();
  @override
  Future<void> writeSuccessfulObservation(WalletSyncReceipt receipt) async =>
      _readOnly();
  @override
  Future<void> writeDeletionMarker(
    WalletNetworkKey key,
    WalletDeletionPhase phase,
  ) async => _readOnly();
  @override
  Future<void> clear(WalletNetworkKey key) async => _readOnly();

  Never _readOnly() => throw StateError('Local history metadata is read-only');
}
