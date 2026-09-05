import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/transaction_position.dart';
import '../domain/entities/wallet_sync_receipt.dart';
import '../domain/entities/wallet_transaction.dart';
import '../domain/entities/wallet_transaction_observation.dart';
import '../domain/entities/wallet_transaction_page.dart';
import '../domain/entities/wallet_transaction_snapshot.dart';
import '../domain/entities/wallet_transaction_sync_outcome.dart';
import '../domain/ports/wallet_sync_metadata_port.dart';
import '../domain/ports/wallet_transaction_source_port.dart';
import '../domain/repositories/wallet_transaction_repository.dart';
import '../domain/requests/requests.dart';
import '../domain/wallet_network_key.dart';
import '../domain/wallet_source_registration.dart';
import '../domain/wallet_transaction_sync_failure.dart';
import '../domain/wallet_transaction_sync_state.dart';
import '../wallet_source_operation_coordinator.dart';
import 'memory/in_memory_wallet_transaction_snapshot_store.dart';

typedef _LocalRefreshFlightKey = ({
  WalletNetworkKey key,
  String sourceKind,
  String configurationFingerprint,
});

final class WalletTransactionRepositoryImpl
    implements WalletTransactionRepository {
  final WalletTransactionSourcePort source;
  final WalletSyncMetadataPort metadata;
  final WalletSourceOperationCoordinator coordinator;
  final InMemoryWalletTransactionSnapshotStore store;
  final DateTime Function() now;
  final Map<WalletNetworkKey, WalletTransactionSyncState> _states = {};
  final Map<WalletNetworkKey, StreamController<WalletTransactionSyncState>>
  _controllers = {};
  final Map<
    _LocalRefreshFlightKey,
    Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
  >
  _localRefreshFlights = {};

  WalletTransactionRepositoryImpl({
    required this.source,
    required this.metadata,
    required this.coordinator,
    InMemoryWalletTransactionSnapshotStore? store,
    DateTime Function()? now,
  }) : store = store ?? InMemoryWalletTransactionSnapshotStore(),
       now = now ?? DateTime.now;

  WalletTransactionSyncState _state(WalletNetworkKey key) =>
      _states[key] ?? const WalletStateUninitialized();

  void _emit(WalletNetworkKey key, WalletTransactionSyncState state) {
    _states[key] = state;
    (_controllers[key] ??=
            StreamController<WalletTransactionSyncState>.broadcast(sync: true))
        .add(state);
  }

  @override
  Stream<WalletTransactionSyncState> watch(WalletNetworkKey key) {
    final controller = _controllers[key] ??=
        StreamController<WalletTransactionSyncState>.broadcast(sync: true);
    late StreamSubscription<WalletTransactionSyncState> subscription;
    final subscriber = StreamController<WalletTransactionSyncState>(sync: true);
    subscriber.onListen = () {
      subscription = controller.stream.listen(
        subscriber.add,
        onDone: subscriber.close,
      );
      subscriber.add(_state(key));
    };
    subscriber.onCancel = () => subscription.cancel();
    return subscriber.stream;
  }

  /// Closes every state stream. For application shutdown; the repository is
  /// unusable for watching afterwards.
  Future<void> dispose() async {
    final controllers = _controllers.values.toList();
    _controllers.clear();
    for (final controller in controllers) {
      await controller.close();
    }
  }

  int? _revision(WalletNetworkKey key) => store.read(key)?.revision;

  WalletTransactionSyncFailure _map(Object error) {
    if (error is WalletTransactionSyncFailure) return error;
    if (error is TimeoutException) return const CoordinationTimeoutFailure();
    return const SourceFailure(SourceFailureReason.unknown);
  }

  bool _registrationMatches(
    WalletSourceRegistration registration,
    WalletSyncMetadata? value,
  ) =>
      value == null ||
      (value.registration.sourceKind == registration.sourceKind &&
          value.registration.configurationFingerprint ==
              registration.configurationFingerprint);

  @override
  Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
  refresh(RefreshLocalSnapshotRequest request) {
    final registration = request.registration;
    final flightKey = (
      key: registration.key,
      sourceKind: registration.sourceKind,
      configurationFingerprint: registration.configurationFingerprint,
    );
    final inFlight = _localRefreshFlights[flightKey];
    if (inFlight != null) return inFlight;

    final refresh = _run(registration, local: true, discover: false);
    _localRefreshFlights[flightKey] = refresh;
    void clearFlight() {
      if (identical(_localRefreshFlights[flightKey], refresh)) {
        _localRefreshFlights.remove(flightKey);
      }
    }

    unawaited(
      refresh.then<void>(
        (_) => clearFlight(),
        onError: (Object _, StackTrace _) => clearFlight(),
      ),
    );
    return refresh;
  }

  @override
  Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
  synchronize(SynchronizeWalletRequest request) =>
      _run(request.registration, local: false, discover: false);

  @override
  Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
  discover(DiscoverWalletHistoryRequest request) =>
      _run(request.registration, local: false, discover: true);

  Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
  _run(
    WalletSourceRegistration registration, {
    required bool local,
    required bool discover,
  }) async {
    final key = registration.key;
    var existing = await metadata.read(key);
    if (existing?.deletionPending == true) {
      final resumed = await _delete(key, registration: registration);
      if (resumed case Err(:final failure)) return Err(failure);
      // The resumed deletion cleared the stored registration; re-read so a
      // revival with a replacement registration is not judged against it.
      existing = await metadata.read(key);
    }
    if (_state(key) is WalletStateDeleted && !discover) {
      return Err(const DeletedWalletFailure());
    }
    if (!_registrationMatches(registration, existing)) {
      _emit(key, WalletStateRegistrationMismatch(_revision(key)));
      return Err(const WalletRegistrationMismatchFailure());
    }

    _emit(
      key,
      local
          ? WalletStateLoadingLocal(_revision(key))
          : WalletStateSyncing(_revision(key)),
    );
    try {
      if (!local) await metadata.writeAttempt(key, now());
      final result = await coordinator.runExclusive(
        WalletSourceKey(key.walletId, key.chain, key.network),
        (session) async {
          final result = local
              ? await source.refreshLocal(registration, session)
              : await source.synchronize(
                  registration,
                  session,
                  discover: discover,
                );
          return result;
        },
        allowRetired: discover,
      );
      if (result case Err(:final failure)) {
        _emit(
          key,
          WalletStateFailed(
            _revision(key),
            failure,
            store.read(key)?.lastSuccessfulSyncAt,
          ),
        );
        return Err(failure);
      }

      final observation =
          (result as Ok<WalletSourceObservation, WalletTransactionSyncFailure>)
              .value;
      if (observation.key != key ||
          observation.registration.key != registration.key ||
          observation.registration.sourceKind != registration.sourceKind ||
          observation.registration.configurationFingerprint !=
              registration.configurationFingerprint) {
        const failure = SourceObservationMismatchFailure();
        _emit(
          key,
          WalletStateFailed(
            _revision(key),
            failure,
            store.read(key)?.lastSuccessfulSyncAt,
          ),
        );
        return const Err(failure);
      }
      final old = store.read(key);
      final fingerprint = _fingerprint(observation);
      final revision = old != null && old.contentFingerprint == fingerprint
          ? old.revision
          : (old?.revision ?? 0) + 1;
      final observed = now();
      DateTime? durable;
      MetadataPersistenceWarning? warning;

      if (local) {
        final receipt = await metadata.readReceipt(key);
        if (receipt?.contentFingerprint == fingerprint) {
          durable = receipt?.successfulAt;
        }
      } else {
        final receipt = WalletSyncReceipt(
          key: key,
          successfulAt: observed,
          contentFingerprint: fingerprint,
        );
        try {
          await metadata.writeSuccess(key, observed, fingerprint);
          await metadata.writeReceipt(receipt);
          durable = observed;
        } catch (_) {
          warning = const MetadataPersistenceWarning();
        }
      }

      final snapshot = WalletTransactionSnapshot(
        key: key,
        revision: revision,
        contentFingerprint: fingerprint,
        transactions: observation.transactions,
        observedAt: observed,
        lastSuccessfulSyncAt: durable,
        sourceKind: registration.sourceKind,
        capabilities: observation.capabilities,
        sourceTip: observation.sourceTip,
        complete: observation.complete,
        evidenceLevel: observation.evidenceLevel,
      );
      store.publish(snapshot);
      _emit(
        key,
        warning == null
            ? WalletStateReady(revision, durable)
            : WalletStateReadyWithWarning(revision, observed, warning),
      );
      if (discover) {
        await coordinator.runExclusive<void>(
          WalletSourceKey(key.walletId, key.chain, key.network),
          (session) async => session.reactivate(),
          allowRetired: true,
        );
      }
      return Ok(WalletTransactionSyncOutcome(snapshot, warning: warning));
    } catch (error) {
      final failure = _map(error);
      _emit(
        key,
        WalletStateFailed(
          _revision(key),
          failure,
          store.read(key)?.lastSuccessfulSyncAt,
        ),
      );
      return Err(failure);
    }
  }

  @override
  Future<Result<WalletTransactionObservation?, WalletTransactionSyncFailure>>
  lookup(LookupLocalTransactionRequest request) async {
    final snapshot = store.read(request.key);
    if (snapshot == null) return Err(const SnapshotNotInitializedFailure());
    return Ok(snapshot.lookup(request.txid));
  }

  @override
  Future<Result<WalletTransactionPage, WalletTransactionSyncFailure>> list(
    ListLocalTransactionsRequest request,
  ) async {
    final snapshot = store.read(request.key);
    if (snapshot == null) return Err(const SnapshotNotInitializedFailure());
    final parsed = _parseCursor(request.cursor, snapshot.revision);
    if (parsed is _ExpiredCursor) return Err(const SnapshotExpiredFailure());
    if (parsed is _InvalidCursor || request.pageSize <= 0) {
      return Err(const InvalidPaginationFailure());
    }
    final offset = parsed as int;
    if (offset < 0 || offset > snapshot.transactions.length) {
      return Err(const InvalidPaginationFailure());
    }
    final end = (offset + request.pageSize).clamp(
      0,
      snapshot.transactions.length,
    );
    final items = snapshot.transactions
        .sublist(offset, end)
        .map((transaction) => snapshot.lookup(transaction.txid)!)
        .toList();
    return Ok(
      WalletTransactionPage(
        items,
        end < snapshot.transactions.length ? '$end:${snapshot.revision}' : null,
        snapshot.revision,
      ),
    );
  }

  Object _parseCursor(String? cursor, int revision) {
    if (cursor == null) return 0;
    final parts = cursor.split(':');
    if (parts.length != 2) return const _InvalidCursor();
    final offset = int.tryParse(parts[0]);
    final cursorRevision = int.tryParse(parts[1]);
    if (offset == null || cursorRevision == null) return const _InvalidCursor();
    if (cursorRevision != revision) return const _ExpiredCursor();
    return offset;
  }

  @override
  Future<Result<void, WalletTransactionSyncFailure>> delete(
    WalletNetworkKey key,
  ) => _delete(key);

  Future<Result<void, WalletTransactionSyncFailure>> _delete(
    WalletNetworkKey key, {
    WalletSourceRegistration? registration,
  }) async {
    try {
      final metadataValue = await metadata.read(key);
      if (_state(key) is WalletStateDeleted &&
          metadataValue?.deletionPending != true) {
        return const Ok(null);
      }
      return await coordinator
          .runExclusive<Result<void, WalletTransactionSyncFailure>>(
            WalletSourceKey(key.walletId, key.chain, key.network),
            (session) async {
              await metadata.writeDeletionMarker(
                key,
                WalletDeletionPhase.markerWritten,
              );
              store.evict(key);
              if (_state(key) is! WalletStateDeleted) {
                _emit(key, const WalletStateDeleted());
              }
              await metadata.writeDeletionMarker(
                key,
                WalletDeletionPhase.snapshotEvicted,
              );
              final sourceResult = await source.delete(
                key,
                session,
                registration: registration,
              );
              if (sourceResult case Err(:final failure)) {
                final deletionFailure = failure is DeletionFailure
                    ? failure
                    : const DeletionFailure();
                _emit(key, WalletStateFailed(null, deletionFailure, null));
                return Err(deletionFailure);
              }
              await metadata.writeDeletionMarker(
                key,
                WalletDeletionPhase.sourceDeleted,
              );
              await metadata.clear(key);
              session.retire();
              // The deleted state stays replayable through _states; the
              // controller is closed so subscribers complete and the map
              // does not grow with dead keys.
              await _controllers.remove(key)?.close();
              return const Ok(null);
            },
          );
    } catch (error) {
      final failure = error is TimeoutException
          ? const CoordinationTimeoutFailure()
          : const DeletionFailure();
      _emit(key, WalletStateFailed(_revision(key), failure, null));
      return Err(failure);
    }
  }

  String _fingerprint(WalletSourceObservation observation) {
    final transactions = observation.transactions.map(_transactionData).toList()
      ..sort((a, b) => (a['txid'] as String).compareTo(b['txid'] as String));
    // Observation-method metadata (capabilities, evidence level) is
    // deliberately excluded: a local reconstruction of identical content must
    // reproduce the fingerprint of the network observation, otherwise the
    // durable receipt can never be re-attached after a restart.
    final data = <String, Object?>{
      'transactions': transactions,
      'tip': observation.sourceTip,
      'complete': observation.complete,
    };
    return sha256.convert(utf8.encode(jsonEncode(_canonical(data)))).toString();
  }

  Map<String, Object?> _transactionData(WalletTransaction transaction) => {
    'txid': transaction.txid,
    'amount': transaction.amountSats,
    'fee': transaction.feeSats,
    'inputs': transaction.inputs
        .map((input) => {'txid': input.txid, 'vout': input.vout})
        .toList(),
    'outputs': transaction.outputs
        .map((output) => {'value': output.valueSats, 'script': output.script})
        .toList(),
    'position': _positionData(transaction.position),
    'evidence': transaction.evidence,
    'details': transaction.details,
  };

  Object _positionData(TransactionPosition position) => switch (position) {
    AnchoredPosition(:final blockHash, :final height, :final time) => {
      'kind': 'anchored',
      'blockHash': blockHash,
      'height': height,
      'time': time.toUtc().toIso8601String(),
    },
    SourceReportedConfirmedPosition(:final height, :final time) => {
      'kind': 'sourceConfirmed',
      'height': height,
      'time': time?.toUtc().toIso8601String(),
    },
    UnconfirmedPosition(:final firstSeen, :final lastSeen) => {
      'kind': 'unconfirmed',
      'firstSeen': firstSeen.toUtc().toIso8601String(),
      'lastSeen': lastSeen.toUtc().toIso8601String(),
    },
    ConflictedPosition(:final replacingTxid) => {
      'kind': 'conflicted',
      'replacingTxid': replacingTxid,
    },
    EvictedPosition(:final lastSeen) => {
      'kind': 'evicted',
      'lastSeen': lastSeen.toUtc().toIso8601String(),
    },
    UnknownPosition() => {'kind': 'unknown'},
  };

  Object? _canonical(Object? value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return <String, Object?>{
        for (final entry in entries)
          entry.key.toString(): _canonical(entry.value),
      };
    }
    if (value is Iterable) return value.map(_canonical).toList();
    return value;
  }
}

final class _ExpiredCursor {
  const _ExpiredCursor();
}

final class _InvalidCursor {
  const _InvalidCursor();
}
