import '../../domain/entities/cbf_relay_state.dart';
import '../../domain/repositories/cbf_transaction_repository.dart';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:primitives/primitives.dart';

import '../../domain/entities/bitcoin_sync_progress.dart';
import '../../domain/entities/wallet_source_sync_observation.dart';
import '../../domain/entities/wallet_transaction_sync_outcome.dart';
import '../../domain/ports/wallet_sync_metadata_port.dart';
import '../../domain/wallet_network_key.dart';
import '../../domain/wallet_source_configuration.dart';
import '../../domain/wallet_source_registration.dart';
import '../../domain/wallet_transaction_sync_failure.dart';
import '../../wallet_source_operation_coordinator.dart';
import '../../wallet_source_session.dart';
import 'bdk_cbf_node.dart';
import 'bdk_wallet_transaction_mapper.dart';

typedef CbfOutcome =
    Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>;
typedef CbfPublish =
    Future<CbfOutcome> Function(
      WalletSourceRegistration registration,
      WalletSourceSyncObservation observation,
      bool recovery,
      WalletSourceSession session,
    );

/// One network node owns immutable script indexes, never a durable wallet writer.
/// Storage handles exist only in short coordinated prepare/apply sessions.
final class BdkCbfService
    implements BitcoinSyncProgressRepository, CbfTransactionRepository {
  final WalletCbfMetadataPort metadata;
  final WalletSourceOperationCoordinator coordinator;
  final CbfPublish publish;
  final Future<void> Function(WalletSourceRegistration)? onTransactionChanged;
  final void Function(WalletNetworkKey)? onStarting;
  final void Function(WalletNetworkKey, WalletTransactionSyncFailure)?
  onFailure;
  final Future<bool> Function(WalletSourceRegistration)? isCurrent;
  final BdkCbfReactiveNodeFactory nodeFactory;
  Future<bool> Function(SendPort)? nativeOwnerMonitor;
  final Duration pollInterval;
  final Duration joinTimeout;
  final Duration peerTimeout;
  final Duration broadcastTimeout;
  final Map<String, _NetworkNode> _nodes = {};
  final Map<WalletNetworkKey, BitcoinSyncProgress> _last = {};
  final _events = StreamController<BitcoinSyncProgress>.broadcast();
  Future<void> _changes = Future.value();
  final _applications = <Future<void>>{};

  Future<T> _application<T>(Future<T> Function() action) async {
    final done = Completer<void>();
    _applications.add(done.future);
    try {
      return await action();
    } finally {
      done.complete();
      _applications.remove(done.future);
    }
  }

  Future<void> _drainApplications() async {
    while (_applications.isNotEmpty) {
      await Future.wait(_applications.toList());
    }
  }

  bool _disposed = false;
  bool _foregroundActive = true;

  void setForegroundActive(bool value) {
    _foregroundActive = value;
  }

  int _operationId = 0;
  int _epoch = 0;

  BdkCbfService({
    required this.metadata,
    required this.coordinator,
    required this.publish,
    this.onTransactionChanged,
    this.onStarting,
    this.onFailure,
    this.isCurrent,
    this.nodeFactory = NativeBdkCbfReactiveNode.create,
    this.pollInterval = BdkCbfConfiguration.ownerPollInterval,
    this.joinTimeout = const Duration(seconds: 1),
    this.peerTimeout = const Duration(minutes: 10),
    this.broadcastTimeout = const Duration(seconds: 30),
  });

  @override
  Stream<BitcoinSyncProgress> watchBitcoinSyncProgress(WalletNetworkKey key) =>
      Stream.multi((controller) {
        final subscription = _events.stream
            .where((event) => event.key == key)
            .listen(controller.add, onDone: controller.close);
        final last = _last[key];
        if (last != null) controller.add(last);
        controller.onCancel = subscription.cancel;
      });

  void _emit(
    _Wallet entry, {
    BitcoinSyncPhase? phase,
    int? reached,
    int? target,
    double? fraction,
    int? peers,
    WalletTransactionSyncFailure? failure,
  }) {
    if (_disposed) return;
    final saved = _last[entry.registration.key];
    final previous = saved?.operationId == entry.operationId ? saved : null;
    final value = BitcoinSyncProgress(
      key: entry.registration.key,
      phase: phase ?? previous?.phase ?? BitcoinSyncPhase.findingPeers,
      reachedHeight: reached ?? previous?.reachedHeight,
      targetHeight: target ?? previous?.targetHeight,
      fraction: fraction,
      connectedPeers: peers ?? previous?.connectedPeers,
      isRecovery: entry.recovery,
      operationId: entry.operationId,
      policyFingerprint: entry.configuration.scanPolicyFingerprint,
      startedAt: entry.startedAt,
      startHeight: entry.recovery
          ? entry.configuration.checkpoint.height
          : null,
      failure: failure,
    );
    _last[value.key] = value;
    if (phase == BitcoinSyncPhase.findingPeers &&
        saved?.operationId != entry.operationId) {
      onStarting?.call(value.key);
    }
    _events.add(value);
    if (failure != null) onFailure?.call(value.key, failure);
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _changes.then((_) => action());
    _changes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  /// Reconcile the complete foreground registry (or all eligible background wallets).
  Future<Result<void, WalletTransactionSyncFailure>> reconcile(
    List<WalletSourceRegistration> registrations, {
    bool allowInitialScan = true,
    WalletOperationPriority priority = WalletOperationPriority.foreground,
  }) {
    final epoch = _epoch;
    return _serialize(() async {
      if (_disposed || !_foregroundActive || epoch != _epoch) {
        return const Err(WalletSyncDeferredFailure());
      }
      final groups = <String, List<WalletSourceRegistration>>{};
      for (final registration in registrations) {
        if (registration.configuration is! BdkCbfConfiguration) continue;
        final deadline =
            (registration.configuration as BdkCbfConfiguration).deadline;
        if (deadline != null && !deadline.isAfter(DateTime.now().toUtc())) {
          return const Err(WalletSyncDeferredFailure());
        }
        groups
            .putIfAbsent(registration.key.network, () => [])
            .add(registration);
      }
      for (final network in {..._nodes.keys, ...groups.keys}) {
        final wanted = groups[network] ?? [];
        final old = _nodes[network];
        if (old != null &&
            old.matches(wanted) &&
            !old.stopping &&
            !_running(old)) {
          // Reconciliation can observe overflow before the next timer tick.
          // Finish that generation's FIFO drain before considering replacement.
          _tick(old);
          await old.loop;
        }
        if (old != null &&
            old.matches(wanted) &&
            !old.stopping &&
            _running(old) &&
            await _coversScripts(
              old,
              deadline: wanted.firstOrNull == null
                  ? null
                  : (wanted.first.configuration as BdkCbfConfiguration)
                        .deadline,
            )) {
          continue;
        }
        if (old != null) {
          // Each node owns immutable script indexes and prepared batches.
          // Replace it on policy changes so an old queued boundary can never
          // complete the new discovery policy.
          final stopped = await _stop(old);
          if (!stopped) return const Err(CbfNodeDidNotStopFailure());
          _nodes.remove(network);
        }
        if (wanted.isEmpty) continue;
        final result = await _start(
          network,
          wanted,
          allowInitialScan,
          priority,
          epoch,
        );
        if (result case Err(:final failure)) return Err(failure);
      }
      return const Ok(null);
    });
  }

  Future<Result<void, WalletTransactionSyncFailure>> _start(
    String network,
    List<WalletSourceRegistration> registrations,
    bool allowInitialScan,
    WalletOperationPriority priority,
    int epoch,
  ) async {
    final prepared = <_Prepared>[];
    final entries = <_Wallet>[];
    _NetworkNode? candidate;
    var started = false;
    try {
      for (final registration in registrations) {
        final configuration = registration.configuration as BdkCbfConfiguration;
        final entry = _Wallet(registration, ++_operationId);
        entries.add(entry);
        _remaining(configuration);
        if (configuration.torRequired && configuration.socksPort == null) {
          throw const _Failure(CbfTorUnavailableFailure());
        }
        if (entries.isNotEmpty &&
            (entries.first.configuration.torRequired !=
                    configuration.torRequired ||
                entries.first.configuration.socksPort !=
                    configuration.socksPort)) {
          throw const _Failure(CbfTorUnavailableFailure());
        }
        final snapshot = await coordinator.runExclusive(
          _key(registration),
          (session) async {
            session.ensureOpen();
            _remaining(configuration);
            if (!await _current(registration)) {
              throw const _Failure(WalletSyncDeferredFailure());
            }
            _remaining(configuration);
            final complete = await metadata.isCbfDiscoveryComplete(
              registration.key,
              configuration.scanPolicyFingerprint,
            );
            _remaining(configuration);
            // A missing/replaced SDK store cannot inherit a completion marker.
            if (!allowInitialScan &&
                (!complete ||
                    !File(configuration.databaseFilePath).existsSync())) {
              throw const _Failure(InitialScanRequiredFailure());
            }
            final opened = _OpenWallet.open(configuration);
            var transferred = false;
            try {
              entry.recovery = !complete || _height(opened.wallet) == 0;
              if (entry.recovery && !allowInitialScan) {
                throw const _Failure(InitialScanRequiredFailure());
              }
              if (entry.recovery) {
                _insert(opened, configuration);
                // A changed birthday on a wallet already at tip cannot lower its
                // latest checkpoint. Build a separate watch-only chain anchor;
                // all real transactions and user data stay in the durable store.
                final anchor = _OpenWallet.open(configuration, memory: true);
                var anchorTransferred = false;
                try {
                  _insert(anchor, configuration);
                  for (final keychain in [
                    bdk.KeychainKind.external_,
                    bdk.KeychainKind.internal,
                  ]) {
                    final index = opened.wallet.nextDerivationIndex(
                      keychain: keychain,
                    );
                    if (index > 0) {
                      final addresses = anchor.wallet.revealAddressesTo(
                        keychain: keychain,
                        index: index - 1,
                      );
                      for (final info in addresses) {
                        info.address.dispose();
                      }
                    }
                  }
                  anchorTransferred = true;
                  return _Prepared(anchor, entry);
                } finally {
                  if (!anchorTransferred) anchor.dispose();
                }
              }
              transferred = true;
              return _Prepared(opened, entry);
            } finally {
              if (!transferred) opened.dispose();
            }
          },
          timeout: null,
          admissionDeadline: configuration.deadline,
          priority: priority,
        );
        prepared.add(snapshot);
        _emit(entry, phase: BitcoinSyncPhase.findingPeers);
      }
      if (_disposed || !_foregroundActive || epoch != _epoch) {
        return const Err(WalletSyncDeferredFailure());
      }
      for (final registration in registrations) {
        _remaining(registration.configuration as BdkCbfConfiguration);
      }
      for (final value in prepared) {
        value.entry.externalEnd = _scriptEnd(
          value.opened.wallet,
          bdk.KeychainKind.external_,
        );
        value.entry.internalEnd = _scriptEnd(
          value.opened.wallet,
          bdk.KeychainKind.internal,
        );
      }
      final node = nodeFactory(
        prepared.map((value) => value.opened.wallet).toList(),
        entries.first.configuration,
      );
      final active = _NetworkNode(
        network,
        node,
        entries,
        priority,
        priority == WalletOperationPriority.background
            ? registrations
            : entries.map((entry) => entry.registration).toList(),
        allowInitialScan,
        epoch,
      );
      candidate = active;
      _nodes[network] = active;
      for (final value in prepared) {
        active.byDescriptor[value.opened.wallet.descriptorId(
              keychain: bdk.KeychainKind.external_,
            )] =
            value.entry;
      }
      if (active.byDescriptor.length != entries.length) {
        throw const _Failure(SourceObservationMismatchFailure());
      }
      final monitor = await node.prepare();
      if (monitor != null) {
        final register = nativeOwnerMonitor;
        if (register == null) {
          monitor.send(['untracked']);
        } else if (!await register(monitor)) {
          monitor.send(['untracked']);
          throw const _Failure(CbfNodeDidNotStopFailure());
        }
      }
      if (_disposed || !_foregroundActive || epoch != _epoch) {
        throw const _Failure(WalletSyncDeferredFailure());
      }
      node.run();
      active.timer = Timer.periodic(pollInterval, (_) => _tick(active));
      _tick(active);
      started = true;
      return const Ok(null);
    } on _Failure catch (error) {
      return _failedStart(candidate, error.failure, entries);
    } on TimeoutException {
      return _failedStart(
        candidate,
        const WalletSyncDeferredFailure(),
        entries,
      );
    } on Exception {
      return _failedStart(candidate, const SourceStorageFailure(), entries);
    } finally {
      final active = candidate;
      if (!started && active != null && !active.stopping) {
        unawaited(
          _failedStart(active, const SourceStorageFailure()).then<void>((_) {}),
        );
      }
      for (final value in prepared) {
        value.opened.dispose();
      }
    }
  }

  Future<Result<void, WalletTransactionSyncFailure>> _failedStart(
    _NetworkNode? active,
    WalletTransactionSyncFailure failure, [
    List<_Wallet> entries = const [],
  ]) async {
    if (active == null) {
      for (final entry in entries) {
        _emit(entry, failure: failure);
      }
      return Err(failure);
    }
    _fail(active, failure);
    final joined = await _stop(active);
    if (joined && identical(_nodes[active.network], active)) {
      _nodes.remove(active.network);
    }
    return Err(joined ? failure : const CbfNodeDidNotStopFailure());
  }

  Future<bool> _coversScripts(_NetworkNode active, {DateTime? deadline}) async {
    for (final entry in active.entries) {
      try {
        final covered = await coordinator.runExclusive(
          _key(entry.registration),
          (session) async {
            session.ensureOpen();
            if (active.stopping ||
                !await _current(entry.registration) ||
                active.stopping) {
              return false;
            }
            if (!File(entry.configuration.databaseFilePath).existsSync()) {
              return false;
            }
            if (deadline != null &&
                !DateTime.now().toUtc().isBefore(deadline)) {
              throw TimeoutException('CBF deadline');
            }
            final opened = _OpenWallet.open(entry.configuration);
            try {
              final external = opened.wallet.nextDerivationIndex(
                keychain: bdk.KeychainKind.external_,
              );
              final internal = opened.wallet.nextDerivationIndex(
                keychain: bdk.KeychainKind.internal,
              );
              return external <= entry.externalEnd &&
                  internal <= entry.internalEnd;
            } finally {
              opened.dispose();
            }
          },
          timeout: null,
          admissionDeadline: deadline,
          priority: active.priority,
        );
        if (!covered) return false;
      } on Exception {
        return false;
      }
    }
    return true;
  }

  /// Called after revealing receive scripts and before relaying a transaction
  /// that may reveal change. Rebuild only at the captured window boundary.
  Future<Result<void, WalletTransactionSyncFailure>> ensureScriptCoverage(
    WalletNetworkKey key, {
    DateTime? deadline,
  }) {
    final epoch = _epoch;
    return _serialize(() async {
      if (_disposed) return const Err(WalletSyncDeferredFailure());
      final active = _nodes[key.network];
      if (active == null || active.stopping) return const Ok(null);
      if (await _coversScripts(active, deadline: deadline)) {
        return const Ok(null);
      }
      if (!_foregroundActive ||
          epoch != _epoch ||
          (deadline != null && !DateTime.now().toUtc().isBefore(deadline))) {
        return const Err(WalletSyncDeferredFailure());
      }
      if (!await _stop(active)) return const Err(CbfNodeDidNotStopFailure());
      _nodes.remove(key.network);
      return _start(
        key.network,
        active.entries
            .map((entry) => _withDeadline(entry.registration, deadline))
            .toList(),
        true,
        active.priority,
        epoch,
      );
    });
  }

  Future<bool> _current(
    WalletSourceRegistration registration, {
    bool allowInactive = false,
  }) async =>
      !_disposed &&
      (_foregroundActive || allowInactive) &&
      (isCurrent == null || await isCurrent?.call(registration) == true);

  /// No caller holds a source session while waiting for the first boundary.
  Future<CbfOutcome> synchronize(
    WalletSourceRegistration registration, {
    bool allowInitialScan = true,
  }) async {
    var active = _nodes[registration.key.network];
    if (active == null || active.stopping || !active.contains(registration)) {
      final desired = <WalletSourceRegistration>[
        for (final node in _nodes.values)
          for (final entry in node.entries)
            if (entry.registration.key != registration.key) entry.registration,
        registration,
      ];
      final result = await reconcile(
        desired,
        allowInitialScan: allowInitialScan,
      );
      if (result case Err(:final failure)) return Err(failure);
      active = _nodes[registration.key.network];
    }
    final coverage = await ensureScriptCoverage(
      registration.key,
      deadline: (registration.configuration as BdkCbfConfiguration).deadline,
    );
    if (coverage case Err(:final failure)) return Err(failure);
    active = _nodes[registration.key.network];
    final entry = active?.entries
        .where((entry) => entry.registration.key == registration.key)
        .firstOrNull;
    if (entry == null) return const Err(WalletSyncDeferredFailure());
    final last = entry.last;
    if (last != null) return last;
    try {
      final budget = _remaining(
        registration.configuration as BdkCbfConfiguration,
      );
      return budget == null
          ? await entry.first.future
          : await entry.first.future.timeout(budget);
    } on TimeoutException {
      return const Err(WalletSyncDeferredFailure());
    }
  }

  /// One bounded catch-up across every eligible wallet; first recoveries are
  /// excluded individually. All results are cached before native shutdown.
  Future<Map<WalletNetworkKey, CbfOutcome>> catchUp(
    List<WalletSourceRegistration> registrations,
    DateTime deadline,
  ) async {
    final results = <WalletNetworkKey, CbfOutcome>{};
    final eligible = <WalletSourceRegistration>[];
    Future<void> run() async {
      for (final original in registrations) {
        final registration = _withDeadline(original, deadline);
        final configuration = registration.configuration as BdkCbfConfiguration;
        WalletTransactionSyncFailure? eligibility;
        try {
          eligibility = await coordinator.runExclusive(
            _key(registration),
            (session) async {
              session.ensureOpen();
              _remaining(configuration);
              if (!await _current(registration)) {
                return const WalletSyncDeferredFailure();
              }
              _remaining(configuration);
              if (!await metadata.isCbfDiscoveryComplete(
                    registration.key,
                    configuration.scanPolicyFingerprint,
                  ) ||
                  !File(configuration.databaseFilePath).existsSync()) {
                return const InitialScanRequiredFailure();
              }
              _remaining(configuration);
              final opened = _OpenWallet.open(configuration);
              try {
                return _height(opened.wallet) > 0
                    ? null
                    : const InitialScanRequiredFailure();
              } finally {
                opened.dispose();
              }
            },
            timeout: null,
            admissionDeadline: deadline,
            priority: WalletOperationPriority.background,
          );
        } on TimeoutException {
          eligibility = const WalletSyncDeferredFailure();
        } on Exception {
          eligibility = const SourceStorageFailure();
        }
        if (eligibility != null) {
          results[registration.key] = Err(eligibility);
        } else {
          eligible.add(registration);
        }
      }
      if (eligible.isEmpty) return;
      final started = await reconcile(
        eligible,
        allowInitialScan: false,
        priority: WalletOperationPriority.background,
      );
      if (started case Err(:final failure)) {
        for (final registration in eligible) {
          results[registration.key] = Err(failure);
        }
        return;
      }
      await Future.wait(
        eligible.map((registration) async {
          results[registration.key] = await synchronize(
            registration,
            allowInitialScan: false,
          );
        }),
      );
      // Catch-up callers receive the first boundary, but any prepared backlog
      // must be persisted before their finally can stop the shared node.
      await Future.wait(_nodes.values.map((node) => node.loop).nonNulls);
    }

    Future<void>? running;
    try {
      final remaining = deadline.difference(DateTime.now().toUtc());
      if (remaining > Duration.zero) {
        running = run();
        await running.timeout(remaining);
      }
    } on TimeoutException {
      // Admission has its own absolute deadline; drain its cancellation below.
    } on Exception {
      for (final registration in eligible) {
        results.putIfAbsent(
          registration.key,
          () => const Err(SourceStorageFailure()),
        );
      }
    } finally {
      final stopped = await stop();
      await running;
      await _drainApplications();
      if (stopped case Err(:final failure)) {
        for (final registration in eligible) {
          results[registration.key] = Err(failure);
        }
      }
    }
    return Map.unmodifiable({
      for (final registration in registrations)
        registration.key:
            results[registration.key] ?? const Err(WalletSyncDeferredFailure()),
    });
  }

  Future<Result<String, WalletTransactionSyncFailure>> persistPending(
    WalletSourceRegistration registration,
    Uint8List bytes,
  ) async {
    final transaction = bdk.Transaction(transactionBytes: bytes);
    final id = transaction.computeTxid();
    final txid = id.toString();
    id.dispose();
    transaction.dispose();
    try {
      final result = await _withTransaction(
        registration,
        txid,
        () => _persistPending(registration, bytes, newAttempt: true),
      );
      await _notifyTransactionChanged(registration);
      return result;
    } on Exception {
      return const Err(SourceStorageFailure());
    }
  }

  Future<Result<String, WalletTransactionSyncFailure>> _persistPending(
    WalletSourceRegistration registration,
    Uint8List bytes, {
    bool newAttempt = false,
  }) async {
    final configuration = registration.configuration as BdkCbfConfiguration;
    try {
      return await coordinator.runExclusive(_key(registration), (
        session,
      ) async {
        session.ensureOpen();
        if (!await _current(registration, allowInactive: true)) {
          return const Err<String, WalletTransactionSyncFailure>(
            WalletSyncDeferredFailure(),
          );
        }
        final opened = _OpenWallet.open(configuration);
        bdk.Transaction? transaction;
        try {
          transaction = bdk.Transaction(transactionBytes: bytes);
          final stagedId = transaction.computeTxid();
          var wasCanceled = false;
          try {
            final state = (await metadata.readCbfRelayStates(
              registration.key,
            ))[stagedId.toString()];
            wasCanceled = state == CbfRelayState.canceled;
            if (wasCanceled && !newAttempt) {
              return const Err<String, WalletTransactionSyncFailure>(
                CbfTransactionNotRecoverableFailure(),
              );
            }
            // Only local spends need recovery; incoming unconfirmed records
            // have no local relay obligation.
            if (opened.wallet.sentAndReceived(tx: transaction).sent.toSat() >
                0) {
              await metadata.stageCbfTransaction(
                registration.key,
                stagedId.toString(),
              );
            }
          } finally {
            stagedId.dispose();
          }
          opened.wallet.applyUnconfirmedTxs(
            unconfirmedTxs: [
              bdk.UnconfirmedTx(
                tx: transaction,
                lastSeen:
                    DateTime.now().millisecondsSinceEpoch ~/ 1000 +
                    (wasCanceled ? 1 : 0),
              ),
            ],
          );
          opened.wallet.persist(persister: opened.persister);
          final txid = transaction.computeTxid();
          try {
            return Ok<String, WalletTransactionSyncFailure>(txid.toString());
          } finally {
            txid.dispose();
          }
        } on Exception {
          return const Err<String, WalletTransactionSyncFailure>(
            SourceStorageFailure(),
          );
        } finally {
          transaction?.dispose();
          opened.dispose();
        }
      }, timeout: null);
    } on Exception {
      return const Err(SourceStorageFailure());
    }
  }

  Future<Result<String, WalletTransactionSyncFailure>> broadcast(
    WalletSourceRegistration registration,
    Uint8List bytes, {
    bool relayGateHeld = false,
  }) async {
    final configuration = registration.configuration as BdkCbfConfiguration;
    final deadline =
        configuration.deadline ?? DateTime.now().toUtc().add(broadcastTimeout);
    Future<Result<String, WalletTransactionSyncFailure>> operation() async {
      final saved = await _persistPending(registration, bytes);
      if (saved case Err(:final failure)) return Err(failure);
      if (!deadline.isAfter(DateTime.now().toUtc())) {
        return const Err(CbfBroadcastNotRelayedFailure());
      }
      var active = _nodes[registration.key.network];
      if (active == null || active.stopping || !active.contains(registration)) {
        final desired = [
          for (final node in _nodes.values)
            for (final entry in node.entries)
              if (entry.registration.key != registration.key)
                entry.registration,
          _withDeadline(registration, deadline),
        ];
        final started = await reconcile(desired);
        if (started case Err(:final failure)) return Err(failure);
        active = _nodes[registration.key.network];
      }
      final coverage = await ensureScriptCoverage(
        registration.key,
        deadline: (registration.configuration as BdkCbfConfiguration).deadline,
      );
      if (coverage case Err(:final failure)) return Err(failure);
      active = _nodes[registration.key.network];
      if (active == null || active.stopping) {
        return const Err(CbfBroadcastNotRelayedFailure());
      }
      // Admission before native submission is cancelable by the caller's
      // deadline. Only an actual submit must retain the relay gate past it.
      if (!await active.peers.future.timeout(
        deadline.difference(DateTime.now().toUtc()),
      )) {
        return const Err(CbfBroadcastNotRelayedFailure());
      }
      if (active.stopping ||
          !deadline.isAfter(DateTime.now().toUtc()) ||
          !await _current(registration) ||
          active.stopping ||
          !deadline.isAfter(DateTime.now().toUtc())) {
        return const Err(CbfBroadcastNotRelayedFailure());
      }
      final transaction = bdk.Transaction(transactionBytes: bytes);
      try {
        final txid = (saved as Ok<String, WalletTransactionSyncFailure>).value;
        await metadata.writeCbfRelayState(
          registration.key,
          txid,
          CbfRelayState.submitting,
        );
        await _notifyTransactionChanged(registration);
        // Metadata and observers may wait for storage admission. Revalidate
        // the route and deadline after those awaits, at native submission.
        if (active.stopping ||
            !deadline.isAfter(DateTime.now().toUtc()) ||
            !await _current(registration) ||
            active.stopping ||
            !deadline.isAfter(DateTime.now().toUtc())) {
          await metadata.writeCbfRelayState(
            registration.key,
            txid,
            CbfRelayState.notBroadcast,
          );
          await _notifyTransactionChanged(registration);
          return const Err(CbfBroadcastNotRelayedFailure());
        }
        try {
          await active.node.submit(transaction);
        } on Exception {
          await metadata.writeCbfRelayState(
            registration.key,
            txid,
            CbfRelayState.notBroadcast,
          );
          await _notifyTransactionChanged(registration);
          rethrow;
        }
        await metadata.writeCbfRelayState(
          registration.key,
          txid,
          CbfRelayState.relayed,
        );
        await _notifyTransactionChanged(registration);
        return saved;
      } finally {
        transaction.dispose();
      }
    }

    try {
      final remaining = deadline.difference(DateTime.now().toUtc());
      if (remaining <= Duration.zero) {
        return const Err(CbfBroadcastNotRelayedFailure());
      }
      final transaction = bdk.Transaction(transactionBytes: bytes);
      final id = transaction.computeTxid();
      final txid = id.toString();
      id.dispose();
      transaction.dispose();
      if (relayGateHeld) return await operation();
      return await _application(
        () =>
            _withTransaction(registration, txid, operation, deadline: deadline),
      ).timeout(remaining);
    } on TimeoutException {
      return const Err(CbfBroadcastNotRelayedFailure());
    } on Exception {
      return const Err(CbfBroadcastNotRelayedFailure());
    }
  }

  Future<void> _notifyTransactionChanged(
    WalletSourceRegistration registration,
  ) async {
    try {
      await onTransactionChanged?.call(registration);
    } on Exception {
      /* Relay evidence is already durable; observers can reload. */
    }
  }

  /// The relay gate is distinct from the source gate: native network waits
  /// keep recovery serialized without blocking local wallet reads or updates.
  Future<T> _withTransaction<T>(
    WalletSourceRegistration registration,
    String txid,
    Future<T> Function() action, {
    DateTime? deadline,
  }) => coordinator.runExclusive(
    WalletSourceKey(
      '${registration.key.walletId}:$txid',
      'cbf-relay',
      registration.key.network,
    ),
    (_) => action(),
    timeout: null,
    admissionDeadline: deadline,
  );

  Future<Set<String>> notBroadcastTxids(
    bdk.Wallet wallet,
    WalletSourceRegistration registration,
  ) async {
    final states = await metadata.readCbfRelayStates(registration.key);
    final result = <String>{};
    for (final entry in states.entries) {
      final id = bdk.Txid.fromString(hex: entry.key);
      try {
        final canonical = wallet.getTx(txid: id);
        if (canonical == null) continue;
        try {
          if (canonical.chainPosition is bdk.ConfirmedChainPosition) {
            if (entry.value != CbfRelayState.relayed) {
              await metadata.writeCbfRelayState(
                registration.key,
                entry.key,
                CbfRelayState.relayed,
              );
            }
          } else if (entry.value == CbfRelayState.notBroadcast) {
            result.add(entry.key);
          }
        } finally {
          canonical.transaction.dispose();
        }
      } finally {
        id.dispose();
      }
    }
    return result;
  }

  Future<Result<T, WalletTransactionSyncFailure>> _recover<T>(
    WalletSourceRegistration registration,
    String txid,
    Future<Result<T, WalletTransactionSyncFailure>> Function(
      _OpenWallet,
      bdk.CanonicalTx,
      bdk.Txid,
    )
    action,
  ) async {
    if (registration.configuration is! BdkCbfConfiguration) {
      return const Err(CbfTransactionNotRecoverableFailure());
    }
    try {
      return await coordinator.runExclusive(_key(registration), (
        session,
      ) async {
        session.ensureOpen();
        if (!await _current(registration, allowInactive: true)) {
          return Err<T, WalletTransactionSyncFailure>(
            WalletSyncDeferredFailure(),
          );
        }
        final configuration = registration.configuration as BdkCbfConfiguration;
        if (!File(configuration.databaseFilePath).existsSync()) {
          return Err<T, WalletTransactionSyncFailure>(
            WalletSourceStateMissingFailure(),
          );
        }
        final opened = _OpenWallet.open(configuration);
        final id = bdk.Txid.fromString(hex: txid);
        try {
          final recoverable = await notBroadcastTxids(
            opened.wallet,
            registration,
          );
          final canonical = opened.wallet.getTx(txid: id);
          if (canonical == null) {
            return Err<T, WalletTransactionSyncFailure>(
              CbfTransactionNotRecoverableFailure(),
            );
          }
          try {
            if (!recoverable.contains(txid)) {
              return Err<T, WalletTransactionSyncFailure>(
                CbfTransactionNotRecoverableFailure(),
              );
            }
            return await action(opened, canonical, id);
          } finally {
            canonical.transaction.dispose();
          }
        } finally {
          id.dispose();
          opened.dispose();
        }
      }, timeout: null);
    } on Exception {
      return const Err(SourceStorageFailure());
    }
  }

  @override
  Future<Result<String, WalletTransactionSyncFailure>> retryCbfTransaction(
    WalletSourceRegistration registration,
    String txid,
  ) async {
    try {
      final configuration = registration.configuration;
      final deadline = configuration is BdkCbfConfiguration
          ? configuration.deadline ??
                DateTime.now().toUtc().add(broadcastTimeout)
          : DateTime.now().toUtc().add(broadcastTimeout);
      return await _application(
        () => _withTransaction(registration, txid, () async {
          final bytes = await _recover<Uint8List>(
            registration,
            txid,
            (opened, tx, id) async => Ok(tx.transaction.serialize()),
          );
          return switch (bytes) {
            Err(:final failure) => Err<String, WalletTransactionSyncFailure>(
              failure,
            ),
            Ok(:final value) => await broadcast(
              registration,
              value,
              relayGateHeld: true,
            ),
          };
        }, deadline: deadline),
      ).timeout(deadline.difference(DateTime.now().toUtc()));
    } on TimeoutException {
      return const Err(CbfBroadcastNotRelayedFailure());
    } on Exception {
      return const Err(SourceStorageFailure());
    }
  }

  @override
  Future<Result<void, WalletTransactionSyncFailure>> cancelCbfTransaction(
    WalletSourceRegistration registration,
    String txid,
  ) async {
    try {
      final result = await _withTransaction(
        registration,
        txid,
        () => _recover<void>(registration, txid, (opened, canonical, id) async {
          // Evicting a parent alone does not remove it when a canonical child
          // still depends on it. Never silently cancel another payment.
          var hasChild = false;
          for (final other in opened.wallet.transactions()) {
            try {
              for (final input in other.transaction.input()) {
                final previous = input.previousOutput.txid;
                try {
                  if (previous.toString() == txid) hasChild = true;
                } finally {
                  previous.dispose();
                }
              }
            } finally {
              other.transaction.dispose();
            }
          }
          if (hasChild) return const Err(CbfTransactionNotRecoverableFailure());
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final position = canonical.chainPosition;
          final lastSeen = position is bdk.UnconfirmedChainPosition
              ? position.timestamp ?? now
              : now;
          opened.wallet.applyEvictedTxs(
            evictedTxs: [
              bdk.EvictedTx(
                txid: id,
                evictedAt: lastSeen > now ? lastSeen : now,
              ),
            ],
          );
          final remaining = opened.wallet.getTx(txid: id);
          if (remaining != null) {
            remaining.transaction.dispose();
            return const Err(CbfTransactionNotRecoverableFailure());
          }
          opened.wallet.persist(persister: opened.persister);
          await metadata.writeCbfRelayState(
            registration.key,
            txid,
            CbfRelayState.canceled,
          );
          return const Ok(null);
        }),
        deadline: DateTime.now().toUtc().add(const Duration(seconds: 1)),
      );
      await _notifyTransactionChanged(registration);
      return result;
    } on TimeoutException {
      return const Err(CbfTransactionNotRecoverableFailure());
    } on Exception {
      return const Err(SourceStorageFailure());
    }
  }

  bool _running(_NetworkNode active) {
    final status = active.node.status();
    // Both survive diagnostic eviction and draining. Every native Info kind
    // records peer contact, so even a dropped diagnostic is durable evidence.
    if (status.running &&
        !status.terminated &&
        (status.syncedTip != null || status.infoDropped > 0)) {
      _peerObserved(active);
    }
    status.syncedTip?.hash.dispose();
    return status.running && !status.terminated;
  }

  void _peerObserved(_NetworkNode active) {
    if (active.stopping || active.peers.isCompleted) return;
    // Admission records observed contact, never successful transaction relay.
    // Only submit's native payload acknowledgement can complete a broadcast.
    active.peers.complete(true);
    for (final entry in active.entries) {
      final previous = _last[entry.registration.key];
      _emit(
        entry,
        phase: previous?.phase,
        fraction: previous?.fraction,
        peers: 1,
      );
    }
  }

  void _tick(_NetworkNode active) {
    if (active.stopping || active.rebuilding) return;
    try {
      active.node.renewLease();
    } on bdk.NodeStoppedCbfException {
      // Expired and overflowed nodes still retain complete prepared batches.
    } on Exception {
      _fail(active, const CbfNoPeersFailure());
      _requestStop(active);
      return;
    }
    if (!active.polling) {
      active.polling = true;
      active.loop = _poll(active).whenComplete(() => active.polling = false);
    }
  }

  Future<void> _poll(_NetworkNode active, {bool finalDrain = false}) async {
    try {
      while (!active.stopping) {
        final batch = active.node.pollUpdates();
        if (batch == null) break;
        try {
          if (active.stopping) break;
          for (final item in batch.entries) {
            final entry = active.byDescriptor[item.key];
            if (entry == null) {
              throw const _Failure(SourceObservationMismatchFailure());
            }
            if (active.stopping) break;
            final result = await coordinator.runExclusive(
              _key(entry.registration),
              (session) => _application(() async {
                session.ensureOpen();
                if (active.stopping ||
                    !await _current(entry.registration) ||
                    active.stopping) {
                  return const Err<
                    WalletTransactionSyncOutcome,
                    WalletTransactionSyncFailure
                  >(WalletSyncDeferredFailure());
                }
                final opened = _OpenWallet.open(entry.configuration);
                try {
                  final baseline = mapBdkTransactions(
                    opened.wallet,
                  ).map((tx) => tx.txid).toSet();
                  item.value.apply(opened.wallet);
                  opened.wallet.persist(persister: opened.persister);
                  final reached = _height(opened.wallet);
                  final observation = WalletSourceSyncObservation(
                    observation: mapBdkObservation(
                      opened.wallet,
                      registration: entry.registration,
                      networkOperation: true,
                      discover: entry.recovery,
                      compactBlockFilters: true,
                      notBroadcastTxids: await notBroadcastTxids(
                        opened.wallet,
                        entry.registration,
                      ),
                    ),
                    baselineTxids: baseline,
                  );
                  final result = await publish(
                    entry.registration,
                    observation,
                    entry.recovery,
                    session,
                  );
                  if (result
                      is Ok<
                        WalletTransactionSyncOutcome,
                        WalletTransactionSyncFailure
                      >) {
                    if (entry.recovery) {
                      await metadata.completeCbfDiscovery(
                        entry.registration.key,
                        entry.configuration.scanPolicyFingerprint,
                      );
                    }
                    _emit(
                      entry,
                      phase: BitcoinSyncPhase.done,
                      fraction: 1,
                      reached: reached,
                      target: reached,
                    );
                    entry.recovery = false;
                  }
                  return result;
                } on Exception {
                  return const Err<
                    WalletTransactionSyncOutcome,
                    WalletTransactionSyncFailure
                  >(SourceStorageFailure());
                } finally {
                  opened.dispose();
                }
              }),
              timeout: null,
              admissionDeadline:
                  (active.registrations.first.configuration
                          as BdkCbfConfiguration)
                      .deadline,
              priority: active.priority,
            );
            entry.last = result;
            if (!entry.first.isCompleted) entry.first.complete(result);
            if (result case Err(:final failure)) {
              _emit(entry, failure: failure);
              _requestStop(active);
              break;
            }
          }
        } finally {
          for (final update in batch.values) {
            update.dispose();
          }
        }
      }
      if (active.stopping) return;
      _drainInfo(active);
      active.node.drainWarnings();
      final running = _running(active);
      if (!running) {
        // The native pump can fill its queue between a null poll and status.
        // Once stopped, drain that final prepared boundary before rebuilding.
        if (!finalDrain) {
          await _poll(active, finalDrain: true);
          return;
        }
        active.rebuilding = true;
        unawaited(_rebuild(active));
      } else if (!active.peers.isCompleted &&
          active.age.elapsed >= peerTimeout) {
        _fail(active, const CbfNoPeersFailure());
        _requestStop(active);
      }
    } on TimeoutException {
      if (!active.stopping) {
        _fail(active, const WalletSyncDeferredFailure());
        _requestStop(active);
      }
    } on _Failure catch (error) {
      if (!active.stopping) {
        _fail(active, error.failure);
        _requestStop(active);
      }
    } on Exception {
      if (!active.stopping) {
        _fail(active, const CbfNoPeersFailure());
        _requestStop(active);
      }
    }
  }

  Future<void> _rebuild(_NetworkNode active) => _serialize(() async {
    if (_disposed ||
        !_foregroundActive ||
        active.epoch != _epoch ||
        !identical(_nodes[active.network], active)) {
      return;
    }
    if (!await _stop(active)) {
      _fail(active, const CbfNodeDidNotStopFailure());
      return;
    }
    _nodes.remove(active.network);
    await _start(
      active.network,
      active.registrations,
      active.allowInitialScan,
      active.priority,
      active.epoch,
    );
  });

  void _drainInfo(_NetworkNode active) {
    for (final event in active.node.drainInfo()) {
      // All current Info variants require peer contact. Retained block/filter
      // progress therefore also admits a node whose handshake was evicted.
      _peerObserved(active);
      if (event is bdk.SyncedInfo) {
        event.tip.hash.dispose();
        continue;
      }
      if (active.stopping) break;
      // SyncedInfo acknowledges a prepared native update, never persistence.
      for (final entry in active.entries) {
        final previous = _last[entry.registration.key];
        if (event is bdk.NewChainHeightInfo) {
          if (previous?.phase == BitcoinSyncPhase.done &&
              event.chainHeight <= (previous?.reachedHeight ?? 0)) {
            continue;
          }
          _emit(
            entry,
            phase: BitcoinSyncPhase.checkingBlocks,
            target: event.chainHeight,
          );
        } else if (event is bdk.FiltersProgressInfo) {
          if (previous?.phase == BitcoinSyncPhase.done &&
              event.filtersHeight <= (previous?.reachedHeight ?? 0)) {
            continue;
          }
          _emit(
            entry,
            phase: BitcoinSyncPhase.checkingBlocks,
            reached: event.filtersHeight,
            target: event.chainHeight,
            fraction: event.fraction.clamp(0, 0.999999),
          );
        } else if (event is bdk.BlockReceivedInfo) {
          _emit(entry, phase: BitcoinSyncPhase.downloadingTransactions);
        }
      }
    }
  }

  void _fail(_NetworkNode active, WalletTransactionSyncFailure failure) {
    for (final entry in active.entries) {
      final CbfOutcome result = Err(failure);
      entry.last = result;
      if (!entry.first.isCompleted) entry.first.complete(result);
      _emit(entry, failure: failure);
    }
  }

  void _requestStop(_NetworkNode active) {
    if (active.stopping) return;
    active.stopping = true;
    active.timer?.cancel();
    active.timer = null;
    if (!active.peers.isCompleted) active.peers.complete(false);
    for (final entry in active.entries) {
      if (!entry.first.isCompleted) {
        entry.first.complete(const Err(WalletSyncDeferredFailure()));
      }
    }
    try {
      active.node.shutdown();
    } on Exception {
      /* Still join. */
    }
  }

  bool _joined(_NetworkNode active) {
    if (active.disposed) return true;
    if (!active.node.isTerminated) return false;
    active.timer?.cancel();
    active.node.dispose();
    active.disposed = true;
    return true;
  }

  Future<bool> _stop(_NetworkNode active) async {
    if (active.disposed) return true;
    _requestStop(active);
    final elapsed = Stopwatch()..start();
    while (elapsed.elapsed < joinTimeout * 3) {
      if (_joined(active)) return true;
      await Future<void>.delayed(
        joinTimeout < pollInterval ? joinTimeout : pollInterval,
      );
    }
    active.timer ??= Timer.periodic(pollInterval, (_) {
      if (_joined(active) && active.rebuilding) unawaited(_rebuild(active));
    });
    // A resolver on Tokio's blocking pool may outlive cancellation. Keep handles
    // and the registry barrier until synchronous termination is acknowledged.
    return false;
  }

  /// Invalidate immediately; callers may already hold a wallet/source lock.
  Future<Result<void, WalletTransactionSyncFailure>> stop() async {
    _epoch++;
    final activeNodes = _nodes.values.toList();
    for (final active in activeNodes) {
      _requestStop(active);
    }
    var failed = false;
    final joined = await Future.wait(activeNodes.map(_stop));
    for (var index = 0; index < activeNodes.length; index++) {
      final active = activeNodes[index];
      if (!joined[index]) {
        failed = true;
        continue;
      }
      if (identical(_nodes[active.network], active)) {
        _nodes.remove(active.network);
      }
    }
    if (failed) return const Err(CbfNodeDidNotStopFailure());
    return const Ok(null);
  }

  Future<void> dispose() async {
    _disposed = true;
    final loops = _nodes.values.map((active) => active.loop).nonNulls.toList();
    await stop();
    await _changes;
    await Future.wait(loops);
    await _drainApplications();
    await _events.close();
  }
}

int _scriptEnd(bdk.Wallet wallet, bdk.KeychainKind keychain) {
  final next = wallet.nextDerivationIndex(keychain: keychain);
  return (next > 0 ? next - 1 : 0) + BdkCbfConfiguration.recoveryScriptCount;
}

int _height(bdk.Wallet wallet) {
  final checkpoint = wallet.latestCheckpoint();
  try {
    return checkpoint.height;
  } finally {
    checkpoint.hash.dispose();
  }
}

WalletSourceRegistration _withDeadline(
  WalletSourceRegistration registration,
  DateTime? deadline,
) {
  final configuration = registration.configuration as BdkCbfConfiguration;
  return WalletSourceRegistration.withFingerprint(
    key: registration.key,
    sourceKind: registration.sourceKind,
    configuration: BdkCbfConfiguration(
      externalPublicDescriptor: configuration.externalPublicDescriptor,
      internalPublicDescriptor: configuration.internalPublicDescriptor,
      isTestnet: configuration.isTestnet,
      databaseFilePath: configuration.databaseFilePath,
      checkpoint: configuration.checkpoint,
      torRequired: configuration.torRequired,
      socksPort: configuration.socksPort,
      deadline: deadline,
    ),
  );
}

WalletSourceKey _key(WalletSourceRegistration registration) => WalletSourceKey(
  registration.key.walletId,
  registration.key.chain,
  registration.key.network,
);
Duration? _remaining(BdkCbfConfiguration configuration) {
  final deadline = configuration.deadline;
  if (deadline == null) return null;
  final remaining = deadline.difference(DateTime.now().toUtc());
  if (remaining <= Duration.zero) throw TimeoutException('CBF deadline');
  return remaining;
}

void _insert(_OpenWallet opened, BdkCbfConfiguration configuration) {
  final hash = bdk.BlockHash.fromString(
    hex: configuration.checkpoint.blockHash,
  );
  try {
    opened.wallet.insertCheckpoint(
      blockId: bdk.BlockId(height: configuration.checkpoint.height, hash: hash),
    );
    opened.wallet.persist(persister: opened.persister);
  } finally {
    hash.dispose();
  }
}

final class _OpenWallet {
  final bdk.Wallet wallet;
  final bdk.Persister persister;
  _OpenWallet(this.wallet, this.persister);

  static _OpenWallet open(
    BdkCbfConfiguration configuration, {
    bool memory = false,
  }) {
    final file = File(configuration.databaseFilePath);
    file.parent.createSync(recursive: true);
    final exists = !memory && file.existsSync();
    final persister = memory
        ? bdk.Persister.newInMemory()
        : bdk.Persister.newSqlite(path: file.path);
    bdk.Descriptor? external;
    bdk.Descriptor? internal;
    try {
      external = bdk.Descriptor(
        descriptor: configuration.externalPublicDescriptor,
        networkKind: configuration.isTestnet
            ? bdk.NetworkKind.test
            : bdk.NetworkKind.main,
      );
      internal = bdk.Descriptor(
        descriptor: configuration.internalPublicDescriptor,
        networkKind: configuration.isTestnet
            ? bdk.NetworkKind.test
            : bdk.NetworkKind.main,
      );
      final wallet = exists
          ? bdk.Wallet.load(
              descriptor: external,
              changeDescriptor: internal,
              persister: persister,
              lookahead: BdkCbfConfiguration.recoveryScriptCount,
            )
          : bdk.Wallet(
              descriptor: external,
              changeDescriptor: internal,
              network: configuration.isTestnet
                  ? bdk.Network.testnet
                  : bdk.Network.bitcoin,
              persister: persister,
              lookahead: BdkCbfConfiguration.recoveryScriptCount,
            );
      return _OpenWallet(wallet, persister);
    } catch (_) {
      persister.dispose();
      rethrow;
    } finally {
      external?.dispose();
      internal?.dispose();
    }
  }

  void dispose() {
    wallet.dispose();
    persister.dispose();
  }
}

final class _Prepared {
  final _OpenWallet opened;
  final _Wallet entry;
  _Prepared(this.opened, this.entry);
}

final class _Wallet {
  final WalletSourceRegistration registration;
  final int operationId;
  final DateTime startedAt = DateTime.now().toUtc();
  final Completer<CbfOutcome> first = Completer();
  bool recovery = false;
  late final int externalEnd;
  late final int internalEnd;
  CbfOutcome? last;
  _Wallet(WalletSourceRegistration registration, this.operationId)
    : registration = _withDeadline(registration, null);
  BdkCbfConfiguration get configuration =>
      registration.configuration as BdkCbfConfiguration;
}

final class _NetworkNode {
  final String network;
  final BdkCbfReactiveNode node;
  final List<_Wallet> entries;
  final WalletOperationPriority priority;
  final byDescriptor = <String, _Wallet>{};
  final peers = Completer<bool>();
  final List<WalletSourceRegistration> registrations;
  final bool allowInitialScan;
  final int epoch;
  final age = Stopwatch()..start();
  Future<void>? loop;
  Timer? timer;
  bool polling = false;
  bool rebuilding = false;
  bool disposed = false;
  bool stopping = false;
  _NetworkNode(
    this.network,
    this.node,
    this.entries,
    this.priority,
    this.registrations,
    this.allowInitialScan,
    this.epoch,
  );
  bool contains(WalletSourceRegistration registration) =>
      entries.any((entry) => _same(entry.registration, registration));
  bool matches(List<WalletSourceRegistration> registrations) =>
      registrations.length == entries.length && registrations.every(contains);
}

bool _same(WalletSourceRegistration left, WalletSourceRegistration right) {
  final a = left.configuration as BdkCbfConfiguration;
  final b = right.configuration as BdkCbfConfiguration;
  return left.key == right.key &&
      left.configurationFingerprint == right.configurationFingerprint &&
      a.scanPolicyFingerprint == b.scanPolicyFingerprint &&
      a.torRequired == b.torRequired &&
      a.socksPort == b.socksPort;
}

final class _Failure implements Exception {
  final WalletTransactionSyncFailure failure;
  const _Failure(this.failure);
}
