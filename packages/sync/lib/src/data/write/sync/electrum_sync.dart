import '../../lease_diagnostics.dart';

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import '../../writer_diagnostics.dart';

import 'package:bull_logger/bull_logger.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../native_write_session.dart';
import '../../datasources/revision_store_datasource.dart';
import '../../native_store_paths.dart';
import '../../sqlite_wallet_revision_reader.dart';
import '../writer_session.dart';
import '../writer_sync_operation.dart';
import '../../../domain/native_network_policy.dart';
import '../../../domain/sync_completion.dart';
import '../../../domain/sync_reason.dart';
import '../../../domain/wallet_revision.dart';
import '../../../domain/sync_failure.dart';
import '../../../domain/sync_transaction_target.dart';
import '../../../domain/public_wallet_descriptor.dart';
import '../../../domain/ports/wallet_connection_port.dart';
import '../../../domain/wallet_key.dart';
import '../datasources/bdk_electrum_datasource.dart';
import 'bitcoin_sync_pass.dart';
import 'liquid_sync_pass.dart';
import 'sync_pass.dart';
import 'payment_observation.dart';

/// One Electrum operation inside the writer lease. Headless callers cannot provision or reconcile.
final class ElectrumSync {
  final WalletConnectionPort _connections;
  final Future<Result<WalletRevisionState, SyncFailure>> Function(WalletKey)
  _readRevision;
  final Future<Result<void, SyncFailure>> Function(SyncCompletion)?
  _onCompletion;
  final bool _collectIncoming;
  final Future<String> Function() _documentsDirectory;
  final _active = <WalletKey, _PendingPass>{};
  final _failures = <WalletKey, String>{};
  int _runSequence = 0;
  final _started = StreamController<WalletKey>.broadcast();
  final _runsStarted = StreamController<SyncStarted>.broadcast();
  final _finished = StreamController<SyncFinished>.broadcast();

  ElectrumSync({
    required this._connections,
    required this._documentsDirectory,
    required this._readRevision,
    this._onCompletion,
    this._collectIncoming = false,
  });

  Stream<WalletKey> get started => _started.stream;
  Stream<SyncStarted> get runsStarted => _runsStarted.stream;
  Stream<SyncFinished> get finished => _finished.stream;

  bool isSyncing({String? walletId}) => walletId == null
      ? _active.isNotEmpty
      : _active.keys.any((key) => key.id == walletId);

  /// [collectIncoming] (default: the engine's setting) asks for the wallet's
  /// incoming payment ids in [SyncCompletion.incomingTxids]: `null` there
  /// means they were not collected, an empty set an empty history.
  /// [onCompletion] receives a completion only when they were collected.
  ///
  /// [targets] asks for a targeted pass: the server is asked only about the
  /// wallet scripts those transactions touch, and the completion reports which
  /// of them the pass proved visible. A targeted pass never initializes or
  /// scans a wallet, so it fails with `SyncInitialScanRequiredFailure` on one
  /// that has not completed its initial scan. Only a Bitcoin wallet has
  /// targeted passes: non-empty [targets] on another chain fail with
  /// `SyncUnsupportedNetworkFailure` before any work, never as a routine pass.
  ///
  /// Recoverable outcomes are a [Result]; an unexpected [Exception] becomes a
  /// storage failure. Anything else thrown, a programmer [Error] above all,
  /// completes this future, and every caller joined to it, with that error.
  @useResult
  Future<Result<SyncCompletion, SyncFailure>> execute(
    PublicWalletDescriptor descriptor, {
    bool discover = false,
    SyncReason reason = SyncReason.auto,
    bool headless = false,
    bool allowInitialScan = true,
    bool? collectIncoming,
    List<SyncTransactionTarget> targets = const <SyncTransactionTarget>[],
    Future<Result<void, SyncFailure>> Function(SyncCompletion)? onCompletion,
  }) {
    final failure = nativeDescriptorFailure(descriptor);
    if (failure != null) return Future.value(Err(failure));
    final key = descriptor.key;
    final targeted = targets.isNotEmpty;
    // A targeted pass resolves the wallet's own derivation indices, which only
    // a Bitcoin descriptor has. A Liquid wallet must never satisfy one with a
    // routine Liquid sync that covers no target.
    if (targeted && key.network is! BitcoinNetwork) {
      return Future.value(
        const Err<SyncCompletion, SyncFailure>(SyncUnsupportedNetworkFailure()),
      );
    }
    final previous = _active[key];
    // Joined requests keep the existing pass's reason; each queued discovery owns its reason.
    if (previous != null) {
      // A routine refresh coalesces with a routine pass, which may already be
      // running: it asks only for what that pass already covers.
      if (!targeted && !discover && !previous.targeted) return previous.future;
      // A targeted request coalesces only with a targeted pass that has not
      // started, whose covered scripts it extends. Joining a pass already under
      // way would read a pass that began before this target existed, and its
      // answer would prove nothing about it.
      if (targeted && previous.targeted && !previous.started) {
        previous.targets.addAll(targets);
        return previous.future;
      }
    }
    // A discovery request must not disappear behind a routine sync. Queue it after the current operation; all native access still happens in workers. So does anything the active pass cannot answer, which keeps a single writer per wallet.
    final pass = _PendingPass(targeted: targeted, targets: List.of(targets));
    _active[key] = pass;
    final completer = pass.completer;
    unawaited(() async {
      var runId = 0;
      try {
        // A failed predecessor, whatever it threw, never cancels a queued pass.
        if (previous != null) {
          await previous.future.then<void>((_) {}, onError: (Object _) {});
        }
        // Yield once before fixing the covered scripts: a targeted request
        // issued before this pass actually starts still merges into it, while
        // one issued after gets its own pass.
        await Future<void>.value();
        // The covered scripts are fixed once the pass starts: a later request
        // that arrives from here on gets its own pass.
        pass.started = true;
        final coveredTargets = List<SyncTransactionTarget>.of(pass.targets);
        final watch = Stopwatch()..start();
        runId = ++_runSequence;
        final context =
            'run=$runId chain=${key.network is BitcoinNetwork ? 'bitcoin' : 'liquid'} network=${key.network.env.name} script=${descriptor.scriptType.name} headless=$headless reason=${reason.name}';
        log.fine(
          'Electrum sync started $context discovery=$discover allow_initial_scan=$allowInitialScan targeted=${coveredTargets.length}',
        );
        _started.add(key);
        _runsStarted.add(SyncStarted(key, runId));
        var connectionSummary = 'route=unselected';
        var cacheSummary = '';
        final result = await _run(
          descriptor,
          runId: runId,
          discover: discover,
          headless: headless,
          allowInitialScan: allowInitialScan,
          collectIncoming: collectIncoming ?? _collectIncoming,
          targets: coveredTargets,
          onCompletion: onCompletion ?? _onCompletion,
          onCache: (summary) => cacheSummary = summary,
          onConnection: (connection) {
            connectionSummary =
                'route=${descriptor is LiquidWalletDescriptor || connection.socks5?.isNotEmpty != true ? 'direct' : 'proxy'} stop_gap=${connection.stopGap}';
          },
        );
        switch (result) {
          case Ok(:final value):
            final recovered = _failures.remove(key) != null;
            log.fine(
              'Electrum sync finished $context mode=${value.mode.name} recovered=$recovered revision=${value.revision?.revision ?? 'unknown'} incoming=${value.incomingTxids?.length ?? 'unknown'} elapsed_ms=${watch.elapsedMilliseconds} $connectionSummary $cacheSummary',
            );
          case Err(:final failure):
            final previousFailure = _failures[key];
            _failures[key] = failure.logCode;
            if (previousFailure != failure.logCode) {
              final message =
                  'Electrum sync failed $context category=${failure.logCode} elapsed_ms=${watch.elapsedMilliseconds} $connectionSummary';
              if (failure is SyncStorageFailure) {
                log.severe(
                  message: message,
                  error: 'storage',
                  trace: StackTrace.empty,
                );
              } else {
                log.warning(message);
              }
            }
        }
        _finished.add(SyncFinished(key, result, runId: runId));
        completer.complete(result);
      } on Exception {
        const result = Err<SyncCompletion, SyncFailure>(SyncStorageFailure());
        completer.complete(result);
        _unexpected(key, reason);
        _finished.add(SyncFinished(key, result, runId: runId));
      } catch (error, trace) {
        // Not a recoverable failure: every waiting caller receives the error
        // itself, and indicators still learn that the pass ended.
        completer.completeError(error, trace);
        _unexpected(key, reason);
        _finished.add(
          SyncFinished(key, const Err(SyncStorageFailure()), runId: runId),
        );
      } finally {
        if (identical(_active[key], pass)) {
          _active.remove(key);
        }
      }
    }());
    return completer.future;
  }

  /// Logged once per wallet until a pass succeeds; no foreign detail.
  void _unexpected(WalletKey key, SyncReason reason) {
    if (_failures[key] != 'storage') {
      log.severe(
        message: 'Electrum sync unexpected failure reason=${reason.name}',
        error: 'storage',
        trace: StackTrace.empty,
      );
    }
    _failures[key] = 'storage';
  }

  Future<Result<SyncCompletion, SyncFailure>> _run(
    PublicWalletDescriptor descriptor, {
    required int runId,
    required bool discover,
    required bool headless,
    required bool allowInitialScan,
    required bool collectIncoming,
    required List<SyncTransactionTarget> targets,
    required Future<Result<void, SyncFailure>> Function(SyncCompletion)?
    onCompletion,
    required void Function(WalletConnection) onConnection,
    required void Function(String) onCache,
  }) async {
    final String root;
    try {
      root = await _documentsDirectory();
    } on Exception {
      return const Err(SyncStorageFailure());
    }
    // The caller's reader: this class never opens, let alone creates, a store.
    final state = await _readRevision(descriptor.key);
    final int generation;
    switch (state) {
      case Ok(:final value):
        generation = value.stamp.generation;
      case Err(failure: SyncNotFoundFailure()):
        generation = 0;
      case Err(:final failure):
        if (failure is SyncBusyFailure) {
          LeaseDiagnostics(
            role: LeaseRole.writer,
            intent: LeaseIntent.sync,
            scope: headless ? LeaseScope.headless : LeaseScope.foreground,
          ).busy(LeaseBusySource.revisionRead);
        }
        return Err(failure);
    }
    var retryable = false;
    final events = ReceivePort();
    final subscription = events.listen((message) {
      if (message case (WriterLogLevel level, String text)) {
        persistWriterDiagnostic(level, text);
      } else if (message is SendPort) {
        message.send(null);
      }
    });
    try {
      return await _connections.run(
        network: descriptor.key.network,
        mayRetry: (_) => retryable,
        operation: (connection) async {
          onConnection(connection);
          final attempt = await compute(
            _performSync,
            SyncParams(
              descriptor,
              root,
              connection,
              discover,
              generation,
              events.sendPort,
              headless,
              // A targeted pass judges its targets from the wallet's own
              // scripts; it never initializes one. The preflight check below
              // defers a wallet that has not completed its initial scan.
              allowInitialScan && targets.isEmpty,
              collectIncoming,
              runId,
              targets: targets,
            ),
          );
          retryable = attempt.retryable;
          if (attempt.cacheDiagnostics case final summary?) onCache(summary);
          // Capture foreground visibility immediately on native completion,
          // before Tor teardown or diagnostic flushing can yield to lifecycle changes.
          if (attempt.result case Ok(:final value) when onCompletion != null) {
            if (value.incomingTxids != null) {
              return recordPaymentObservation(attempt.result, onCompletion);
            }
          }
          return attempt.result;
        },
      );
    } finally {
      await subscription.cancel();
      events.close();
      await log.flush();
    }
  }
}

/// One pass of [ElectrumSync], queued or running, with the targets a targeted
/// one must cover. [targets] grows while the pass has not started; [started]
/// marks the instant it fixed them, after which a further request gets its own
/// pass.
final class _PendingPass {
  final Completer<Result<SyncCompletion, SyncFailure>> completer = Completer();
  final bool targeted;
  final List<SyncTransactionTarget> targets;
  bool started = false;

  _PendingPass({required this.targeted, required this.targets});

  Future<Result<SyncCompletion, SyncFailure>> get future => completer.future;
}

Future<SyncPassOutcome> _performSync(SyncParams params) async {
  final key = params.descriptor.key;
  final failure = nativeDescriptorFailure(params.descriptor);
  if (failure != null) {
    return SyncPassOutcome(
      Err<SyncCompletion, SyncFailure>(failure),
      retryable: false,
    );
  }
  // Fail fast before SDK initialization or network access. The writer rechecks
  // existence under its lease; this preliminary check never authorizes creation.
  final path = nativeWalletStoragePath(params.root, key);
  final exists = params.descriptor is LiquidWalletDescriptor
      ? Directory(path).existsSync()
      : File(path).existsSync();
  if (!exists) {
    return SyncPassOutcome(
      const Err<SyncCompletion, SyncFailure>(SyncNotFoundFailure()),
      retryable: false,
    );
  }
  BdkElectrumDatasource? probe;
  try {
    // ⚠️ Liquid probes directly, like the LWK sync that follows: no Tor.
    probe = BdkElectrumDatasource.connect(
      params.connection,
      direct: params.descriptor is LiquidWalletDescriptor,
    );
    probe.ping();
  } on Exception {
    return SyncPassOutcome(
      const Err<SyncCompletion, SyncFailure>(SyncConnectionFailure()),
      retryable: true,
    );
  } finally {
    probe?.dispose();
  }
  if (params.descriptor is LiquidWalletDescriptor) await BullSdk.init();
  final RevisionStoreDatasource revisions;
  try {
    // The foreground created the store before any pass; the worker only opens it.
    revisions = RevisionStoreDatasource.openExisting(
      revisionStorePath(params.root),
    );
  } on RevisionStoreUnavailable {
    return SyncPassOutcome.failed(SyncStorageFailure());
  }
  final reader = SqliteWalletRevisionReader(revisions);
  final writer = WriterSession.worker(
    documentsDirectory: params.root,
    revisions: revisions,
    reader: reader,
    sessions: SdkWriteSessions(params.root),
    descriptor: params.descriptor,
    leaseScope: params.headless ? LeaseScope.headless : LeaseScope.compute,
    diagnostics: (level, message) => params.diagnostics.send((
      level,
      message.startsWith('event=lease_')
          ? message
          : '$message run=${params.runId} headless=${params.headless}',
    )),
  );
  try {
    final current = await reader.read(params.descriptor.key);
    if (current case Ok(value: final state)
        when state.lifecycle == WalletLifecycle.deleted) {
      return SyncPassOutcome(
        const Err<SyncCompletion, SyncFailure>(SyncNotFoundFailure()),
        retryable: false,
      );
    }
    final adopt =
        current is Err ||
        (current as Ok<WalletRevisionState, SyncFailure>)
                .value
                .initializedSchema !=
            writerSchemaVersion;
    if (adopt) {
      if (params.headless) {
        LeaseDiagnostics(
          role: LeaseRole.writer,
          intent: LeaseIntent.sync,
          scope: LeaseScope.headless,
          sink: (level, message) => params.diagnostics.send((level, message)),
        ).busy(switch (current) {
          Err(failure: SyncBusyFailure()) => LeaseBusySource.revisionRead,
          _ => LeaseBusySource.schemaGate,
        });
        return SyncPassOutcome(
          const Err<SyncCompletion, SyncFailure>(SyncBusyFailure()),
          retryable: false,
        );
      }
    }
    final operation = _NativeSyncOperation(params);
    // The foreground adopts, then syncs, under one writer lock acquisition.
    final result = await writer.sync(
      params.descriptor.key,
      expectedGeneration: params.generation,
      operation: operation,
      reconcile: !params.headless,
      adopt: adopt,
      preflight: params.allowInitialScan
          ? null
          : () => checkInitialScan(params),
    );
    return switch (result) {
      Err(:final failure) => SyncPassOutcome(
        Err<SyncCompletion, SyncFailure>(failure),
        retryable: false,
      ),
      Ok(:final value) => SyncPassOutcome(
        operation.result?.map(
              (completion) => completion.committed(value.revision),
            ) ??
            const Err<SyncCompletion, SyncFailure>(SyncStorageFailure()),
        retryable: false,
        cacheDiagnostics: operation.cacheDiagnostics,
      ),
    };
  } finally {
    await reader.close();
    revisions.close();
    // Same-port ordering plus acknowledgement drains all diagnostics before
    // compute returns and the foreground closes its listener.
    final acknowledged = ReceivePort();
    params.diagnostics.send(acknowledged.sendPort);
    await acknowledged.first;
    acknowledged.close();
  }
}

final class _NativeSyncOperation
    implements
        WriterSyncOperation,
        WriterSyncMutation,
        WriterSyncChanges,
        WriterSyncSpendObservation {
  Map<String, Set<String>> _trackedSpends = {};
  @override
  Set<String> observedSpendTransactions = {};
  @override
  Map<String, Set<String>> spendTransactionInputs = {};
  @override
  Set<String> settledSpendTransactions = {};
  @override
  void trackSpendTransactions(Map<String, Set<String>> inputsByTxid) =>
      _trackedSpends = inputsByTxid;
  @override
  bool mayHaveMutated = false;
  @override
  bool hasChanges = true;
  final SyncParams params;
  Result<SyncCompletion, SyncFailure>? result;
  String? cacheDiagnostics;
  _NativeSyncOperation(this.params);
  @override
  Future<Result<void, SyncFailure>> execute(
    PublicWalletDescriptor descriptor, {
    required int? issuedReceiveIndex,
  }) async {
    void reportSpendEvidence(SpendEvidence evidence) {
      observedSpendTransactions = evidence.observed;
      spendTransactionInputs = evidence.inputs;
      settledSpendTransactions = evidence.settled;
    }

    final attempt = switch (descriptor) {
      LiquidWalletDescriptor() => await liquidSyncPass(
        params,
        descriptor,
        issuedReceiveIndex,
        markMutation: () => mayHaveMutated = true,
      ),
      BitcoinWalletDescriptor() => await bitcoinSyncPass(
        params,
        descriptor,
        trackedSpends: _trackedSpends,
        markMutation: () => mayHaveMutated = true,
        reportChanges: (changed) => hasChanges = changed,
        reportSpendEvidence: reportSpendEvidence,
      ),
    };
    result = attempt.result;
    cacheDiagnostics = attempt.cacheDiagnostics;
    return switch (attempt.result) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }
}
