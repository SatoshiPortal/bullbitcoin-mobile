import 'domain/entities/cbf_relay_state.dart';
import 'domain/usecases/retry_cbf_transaction_usecase.dart';
import 'domain/usecases/cancel_cbf_transaction_usecase.dart';
import 'dart:isolate';
import 'data/bdk/bdk_cbf_service.dart';
import 'domain/wallet_source_configuration.dart';
import 'domain/ports/bitcoin_cbf_operations_port.dart';
import 'domain/requests/broadcast_cbf_transaction_request.dart';
import 'domain/usecases/broadcast_cbf_transaction_usecase.dart';
import 'dart:typed_data';
import 'wallet_source_session.dart';
import 'domain/wallet_source_registration.dart';
import 'domain/entities/bitcoin_sync_progress.dart';
import 'domain/usecases/watch_bitcoin_sync_progress_usecase.dart';
import 'domain/entities/wallet_transaction_observation.dart';
import 'domain/entities/wallet_transaction_page.dart';
import 'domain/entities/wallet_transaction_sync_outcome.dart';
import 'domain/requests/requests.dart';
import 'domain/wallet_network_key.dart';
import 'domain/wallet_transaction_sync_failure.dart';
import 'data/bdk/bdk_wallet_transaction_source.dart';
import 'data/lwk/lwk_wallet_transaction_source.dart';
import 'data/wallet_transaction_repository_impl.dart';
import 'domain/wallet_transaction_sync_state.dart';
import 'domain/ports/wallet_transaction_source_port.dart';
import 'domain/ports/wallet_sync_metadata_port.dart';
import 'wallet_source_operation_coordinator.dart';
import 'durable_wallet_source_operation_coordinator.dart'
    show WalletCoordinationLogSink;
import 'domain/usecases/synchronize_wallet_usecase.dart';
import 'domain/usecases/discover_wallet_history_usecase.dart';
import 'domain/usecases/refresh_local_snapshot_usecase.dart';
import 'domain/usecases/lookup_local_transaction_usecase.dart';
import 'domain/usecases/list_local_transactions_usecase.dart';
import 'domain/usecases/watch_wallet_sync_state_usecase.dart';
import 'domain/usecases/delete_wallet_usecase.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class WalletTransactionSyncFacade {
  late final WalletTransactionRepositoryImpl _repository;
  late final SynchronizeWalletUsecase _synchronize;
  late final DiscoverWalletHistoryUsecase _discover;
  late final RefreshLocalSnapshotUsecase _refresh;
  late final LookupLocalTransactionUsecase _lookup;
  late final ListLocalTransactionsUsecase _list;
  late final WatchWalletSyncStateUsecase _watch;
  late final DeleteWalletUsecase _delete;
  late final WatchBitcoinSyncProgressUsecase _progress;
  final WalletTransactionSourcePort _source;
  final Future<void> Function(WalletNetworkKey)? onCbfTransactionChanged;
  late final BroadcastCbfTransactionUsecase _broadcast;
  BdkCbfService? _cbfService;
  final Future<void> Function(
    WalletTransactionSyncOutcome,
    WalletSourceSession,
  )?
  onCbfSnapshot;

  WalletTransactionSyncFacade({
    required WalletTransactionSourcePort source,
    required WalletSyncMetadataPort metadata,
    required WalletSourceOperationCoordinator coordinator,
    DateTime Function()? now,
    Future<bool> Function(WalletSourceRegistration)? isCbfPolicyCurrent,
    this.onCbfSnapshot,
    this.onCbfTransactionChanged,
  }) : _source = source {
    _repository = WalletTransactionRepositoryImpl(
      source: source,
      metadata: metadata,
      coordinator: coordinator,
      now: now,
    );
    _synchronize = SynchronizeWalletUsecase(_repository);
    _discover = DiscoverWalletHistoryUsecase(_repository);
    _refresh = RefreshLocalSnapshotUsecase(_repository);
    _lookup = LookupLocalTransactionUsecase(_repository);
    _list = ListLocalTransactionsUsecase(_repository);
    _watch = WatchWalletSyncStateUsecase(_repository);
    _delete = DeleteWalletUsecase(_repository);
    _progress = WatchBitcoinSyncProgressUsecase(_repository);
    _broadcast = BroadcastCbfTransactionUsecase(_repository);
    if (source is BdkWalletTransactionSource &&
        metadata is WalletCbfMetadataPort) {
      final service = BdkCbfService(
        metadata: metadata as WalletCbfMetadataPort,
        coordinator: coordinator,
        isCurrent: isCbfPolicyCurrent,
        nodeFactory: source.cbfNodeFactory,
        onTransactionChanged: (registration) async {
          final refreshed = await _repository.refresh(
            RefreshLocalSnapshotRequest(registration),
          );
          if (refreshed
              is Ok<
                WalletTransactionSyncOutcome,
                WalletTransactionSyncFailure
              >) {
            await onCbfTransactionChanged?.call(registration.key);
          }
        },
        onFailure: _repository.reportCbfFailure,
        onStarting: _repository.reportCbfStarting,
        publish: (registration, observation, recovery, session) async {
          final result = await _repository.publishCbf(
            registration,
            observation,
            recovery,
            session,
          );
          if (result case Ok(:final value)) {
            await onCbfSnapshot?.call(value, session);
          }
          return result;
        },
      );
      _cbfService = service;
      source.reactive = service;
    }
  }

  /// Composition entry for the packaged BDK Electrum adapter: the adapter
  /// type stays internal to `src/data/`, only this factory is public.
  factory WalletTransactionSyncFacade.bdkElectrum({
    required WalletSyncMetadataPort metadata,
    required WalletSourceOperationCoordinator coordinator,
    DateTime Function()? now,
    WalletCoordinationLogSink? logSink,
    Future<bool> Function(WalletSourceRegistration)? isCbfPolicyCurrent,
    Future<void> Function(WalletTransactionSyncOutcome, WalletSourceSession)?
    onCbfSnapshot,
    Future<void> Function(WalletNetworkKey)? onCbfTransactionChanged,
  }) => WalletTransactionSyncFacade(
    isCbfPolicyCurrent: isCbfPolicyCurrent,
    onCbfSnapshot: onCbfSnapshot,
    onCbfTransactionChanged: onCbfTransactionChanged,
    source: BdkWalletTransactionSource(logSink: logSink),
    metadata: metadata,
    coordinator: coordinator,
    now: now,
  );

  factory WalletTransactionSyncFacade.lwkElectrum({
    required WalletSyncMetadataPort metadata,
    required WalletSourceOperationCoordinator coordinator,
    DateTime Function()? now,
    WalletCoordinationLogSink? logSink,
  }) => WalletTransactionSyncFacade(
    source: LwkWalletTransactionSource(logSink: logSink),
    metadata: metadata,
    coordinator: coordinator,
    now: now,
  );

  /// Closes every state stream. For application shutdown; watchers complete
  /// and the facade must not be used for watching afterwards.
  Future<void> dispose() async {
    await _cbfService?.dispose();
    await _repository.dispose();
    final source = _source;
    if (source is BitcoinCbfOperationsPort) {
      await (source as BitcoinCbfOperationsPort).disposeCbf();
    }
  }

  Stream<BitcoinSyncProgress> watchBitcoinSyncProgress(WalletNetworkKey key) =>
      _progress.execute(key);

  Future<
    Map<
      WalletNetworkKey,
      Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>
    >
  >
  catchUpCbfWallets(
    List<WalletSourceRegistration> registrations, {
    required DateTime deadline,
  }) async {
    for (final registration in registrations) {
      _rememberCbf(registration);
    }
    final service = _cbfService;
    return service == null
        ? {
            for (final registration in registrations)
              registration.key: const Err(CbfRemoteLookupForbiddenFailure()),
          }
        : service.catchUp(registrations, deadline);
  }

  void _rememberCbf(WalletSourceRegistration registration) {
    final source = _source;
    if (source is BdkWalletTransactionSource) {
      source.rememberRegistration(registration);
    }
  }

  /// Registers native termination witnesses before admitting a leased node.
  void setCbfNativeOwnerMonitor(Future<bool> Function(SendPort) monitor) {
    _cbfService?.nativeOwnerMonitor = monitor;
  }

  void setCbfForegroundActive(bool active) =>
      _cbfService?.setForegroundActive(active);

  Future<Result<void, WalletTransactionSyncFailure>> reconcileCbfWallets(
    List<WalletSourceRegistration> registrations, {
    bool allowInitialScan = true,
    WalletOperationPriority priority = WalletOperationPriority.foreground,
  }) async {
    for (final registration in registrations) {
      _rememberCbf(registration);
    }
    return _cbfService?.reconcile(
          registrations,
          allowInitialScan: allowInitialScan,
          priority: priority,
        ) ??
        const Ok(null);
  }

  Future<Result<void, WalletTransactionSyncFailure>> ensureCbfScriptCoverage(
    WalletNetworkKey key,
  ) async => _cbfService?.ensureScriptCoverage(key) ?? const Ok(null);

  Future<Result<void, WalletTransactionSyncFailure>> stopCbfNodes() async =>
      _cbfService?.stop() ?? const Ok(null);

  Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
  _reactiveSynchronize(
    WalletSourceRegistration registration, {
    bool allowInitialScan = true,
    bool discover = false,
  }) async {
    _rememberCbf(registration);
    final prepared = await _repository.prepareCbfRegistration(
      registration,
      discover: discover,
    );
    if (prepared case Err(:final failure)) {
      return Err(failure);
    }
    final service = _cbfService;
    return service == null
        ? const Err(CbfRemoteLookupForbiddenFailure())
        : service.synchronize(registration, allowInitialScan: allowInitialScan);
  }

  /// Saves pending in a short source session before the shell verifies Tor.
  Future<Result<String, WalletTransactionSyncFailure>> stageCbfTransaction({
    required WalletSourceRegistration registration,
    required Uint8List transactionBytes,
  }) async {
    _rememberCbf(registration);
    final service = _cbfService;
    return service == null
        ? const Err(CbfRemoteLookupForbiddenFailure())
        : service.persistPending(registration, transactionBytes);
  }

  /// Broadcasts through the retained node. CBF network waits must enter
  /// without a source session; storage stages acquire their own short session.
  @useResult
  Future<Result<String, WalletTransactionSyncFailure>> broadcastCbfTransaction({
    required WalletSourceRegistration registration,
    required Uint8List transactionBytes,
    WalletSourceSession? session,
  }) {
    final service = _cbfService;
    if (service != null && session == null) {
      return service.broadcast(registration, transactionBytes);
    }
    return _broadcast.execute(
      BroadcastCbfTransactionRequest(
        registration: registration,
        transactionBytes: transactionBytes,
        session: session,
      ),
    );
  }

  Future<void> recordCbfConfirmations(
    WalletNetworkKey key,
    Iterable<String> confirmedTxids,
  ) async {
    final service = _cbfService;
    if (service == null) return;
    final states = await service.metadata.readCbfRelayStates(key);
    for (final txid in confirmedTxids) {
      if (states.containsKey(txid) && states[txid] != CbfRelayState.relayed) {
        await service.metadata.writeCbfRelayState(
          key,
          txid,
          CbfRelayState.relayed,
        );
      }
    }
  }

  @useResult
  Future<Result<String, WalletTransactionSyncFailure>> retryCbfTransaction(
    WalletSourceRegistration registration,
    String txid,
  ) async {
    final service = _cbfService;
    if (service == null) return const Err(CbfRemoteLookupForbiddenFailure());
    final result = await RetryCbfTransactionUsecase(
      service,
    ).execute(registration, txid);
    final refreshed = await refreshLocalSnapshot(
      RefreshLocalSnapshotRequest(registration),
    );
    if (refreshed case Err(:final failure)) return Err(failure);
    return result;
  }

  @useResult
  Future<Result<void, WalletTransactionSyncFailure>> cancelCbfTransaction(
    WalletSourceRegistration registration,
    String txid,
  ) async {
    final service = _cbfService;
    if (service == null) return const Err(CbfRemoteLookupForbiddenFailure());
    final result = await CancelCbfTransactionUsecase(
      service,
    ).execute(registration, txid);
    final refreshed = await refreshLocalSnapshot(
      RefreshLocalSnapshotRequest(registration),
    );
    if (refreshed case Err(:final failure)) return Err(failure);
    return result;
  }

  @useResult
  Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
  synchronizeWallet(SynchronizeWalletRequest request) =>
      request.registration.configuration is BdkCbfConfiguration &&
          request.session == null &&
          _cbfService != null
      ? _reactiveSynchronize(
          request.registration,
          allowInitialScan: request.allowInitialScan,
        )
      : _synchronize.execute(request);
  @useResult
  Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
  discoverWalletHistory(DiscoverWalletHistoryRequest request) =>
      request.registration.configuration is BdkCbfConfiguration &&
          request.session == null &&
          _cbfService != null
      ? _reactiveSynchronize(request.registration, discover: true)
      : _discover.execute(request);
  @useResult
  Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
  refreshLocalSnapshot(RefreshLocalSnapshotRequest request) =>
      _refresh.execute(request);
  @useResult
  Future<Result<WalletTransactionObservation?, WalletTransactionSyncFailure>>
  lookupLocal(LookupLocalTransactionRequest request) =>
      _lookup.execute(request);
  @useResult
  Future<Result<WalletTransactionPage, WalletTransactionSyncFailure>> listLocal(
    ListLocalTransactionsRequest request,
  ) => _list.execute(request);
  Stream<WalletTransactionSyncState> watchWalletState(WalletNetworkKey key) =>
      _watch.execute(key);
  @useResult
  Future<Result<void, WalletTransactionSyncFailure>> deleteWallet(
    WalletNetworkKey key,
  ) => _delete.execute(key);
}
