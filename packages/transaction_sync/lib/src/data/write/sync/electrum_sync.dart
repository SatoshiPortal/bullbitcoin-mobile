import '../../lease_diagnostics.dart';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import '../../writer_diagnostics.dart';

import 'package:bull_logger/bull_logger.dart';
import 'package:bull_sdk/bull_sdk.dart' show BullSdk;
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
import '../../../domain/transaction_sync_failure.dart';
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
  final Future<Result<WalletRevisionState, TransactionSyncFailure>> Function(
    WalletKey,
  )
  _readRevision;
  final Future<Result<void, TransactionSyncFailure>> Function(SyncCompletion)?
  _onCompletion;
  final Future<String> Function() _documentsDirectory;
  final _active =
      <WalletKey, Future<Result<SyncCompletion, TransactionSyncFailure>>>{};
  final _failures = <WalletKey, String>{};
  int _runSequence = 0;
  final _started = StreamController<WalletKey>.broadcast();
  final _finished = StreamController<SyncFinished>.broadcast();

  ElectrumSync({
    required this._connections,
    required this._documentsDirectory,
    required this._readRevision,
    this._onCompletion,
  });

  Stream<WalletKey> get started => _started.stream;
  Stream<SyncFinished> get finished => _finished.stream;

  bool isSyncing({String? walletId}) => walletId == null
      ? _active.isNotEmpty
      : _active.keys.any((key) => key.id == walletId);

  /// Recoverable outcomes are a [Result]; an unexpected [Exception] becomes a
  /// storage failure. Anything else thrown, a programmer [Error] above all,
  /// completes this future, and every caller joined to it, with that error.
  @useResult
  Future<Result<SyncCompletion, TransactionSyncFailure>> execute(
    PublicWalletDescriptor descriptor, {
    bool discover = false,
    SyncReason reason = SyncReason.auto,
    bool headless = false,
    bool allowInitialScan = true,
    Future<Result<void, TransactionSyncFailure>> Function(SyncCompletion)?
    onCompletion,
  }) {
    final failure = nativeDescriptorFailure(descriptor);
    if (failure != null) return Future.value(Err(failure));
    final key = descriptor.key;
    final previous = _active[key];
    // Joined requests keep the existing pass's reason; each queued discovery owns its reason.
    if (previous != null && !discover) return previous;
    // A discovery request must not disappear behind a routine sync. Queue it after the current operation; all native access still happens in workers.
    final completer =
        Completer<Result<SyncCompletion, TransactionSyncFailure>>();
    _active[key] = completer.future;
    unawaited(() async {
      try {
        // A failed predecessor, whatever it threw, never cancels a queued pass.
        if (previous != null) {
          await previous.then<void>((_) {}, onError: (Object _) {});
        }
        final watch = Stopwatch()..start();
        final runId = ++_runSequence;
        final context =
            'run=$runId chain=${key.network is BitcoinNetwork ? 'bitcoin' : 'liquid'} network=${key.network.env.name} script=${descriptor.scriptType.name} headless=$headless reason=${reason.name}';
        log.fine('Electrum sync started $context discovery=$discover');
        _started.add(key);
        var connectionSummary = 'route=unselected';
        var cacheSummary = '';
        final result = await _run(
          descriptor,
          runId: runId,
          discover: discover,
          headless: headless,
          allowInitialScan: allowInitialScan,
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
              if (failure is TransactionSyncStorageFailure) {
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
        _finished.add(SyncFinished(key, result));
        completer.complete(result);
      } on Exception {
        const result = Err<SyncCompletion, TransactionSyncFailure>(
          TransactionSyncStorageFailure(),
        );
        completer.complete(result);
        _unexpected(key, reason);
        _finished.add(SyncFinished(key, result));
      } catch (error, trace) {
        // Not a recoverable failure: every waiting caller receives the error
        // itself, and indicators still learn that the pass ended.
        completer.completeError(error, trace);
        _unexpected(key, reason);
        _finished.add(
          SyncFinished(key, const Err(TransactionSyncStorageFailure())),
        );
      } finally {
        if (identical(_active[key], completer.future)) {
          unawaited(_active.remove(key));
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

  Future<Result<SyncCompletion, TransactionSyncFailure>> _run(
    PublicWalletDescriptor descriptor, {
    required int runId,
    required bool discover,
    required bool headless,
    required bool allowInitialScan,
    required Future<Result<void, TransactionSyncFailure>> Function(
      SyncCompletion,
    )?
    onCompletion,
    required void Function(WalletConnection) onConnection,
    required void Function(String) onCache,
  }) async {
    final String root;
    try {
      root = await _documentsDirectory();
    } on Exception {
      return const Err(TransactionSyncStorageFailure());
    }
    // The caller's reader: this class never opens, let alone creates, a store.
    final state = await _readRevision(descriptor.key);
    final int generation;
    switch (state) {
      case Ok(:final value):
        generation = value.stamp.generation;
      case Err(failure: TransactionSyncNotFoundFailure()):
        generation = 0;
      case Err(:final failure):
        if (failure is TransactionSyncBusyFailure) {
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
              allowInitialScan,
              onCompletion != null,
              runId,
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

Future<SyncPassOutcome> _performSync(SyncParams params) async {
  final key = params.descriptor.key;
  final failure = nativeDescriptorFailure(params.descriptor);
  if (failure != null) {
    return SyncPassOutcome(
      Err<SyncCompletion, TransactionSyncFailure>(failure),
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
      const Err<SyncCompletion, TransactionSyncFailure>(
        TransactionSyncNotFoundFailure(),
      ),
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
      const Err<SyncCompletion, TransactionSyncFailure>(
        TransactionSyncConnectionFailure(),
      ),
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
    return SyncPassOutcome.failed(TransactionSyncStorageFailure());
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
    if (current case Ok(
      value: final state,
    ) when state.lifecycle == WalletLifecycle.deleted) {
      return SyncPassOutcome(
        const Err<SyncCompletion, TransactionSyncFailure>(
          TransactionSyncNotFoundFailure(),
        ),
        retryable: false,
      );
    }
    if (current is Err ||
        (current as Ok<WalletRevisionState, TransactionSyncFailure>)
                .value
                .initializedSchema !=
            writerSchemaVersion) {
      if (params.headless) {
        LeaseDiagnostics(
          role: LeaseRole.writer,
          intent: LeaseIntent.sync,
          scope: LeaseScope.headless,
          sink: (level, message) => params.diagnostics.send((level, message)),
        ).busy(switch (current) {
          Err(failure: TransactionSyncBusyFailure()) =>
            LeaseBusySource.revisionRead,
          _ => LeaseBusySource.schemaGate,
        });
        return SyncPassOutcome(
          const Err<SyncCompletion, TransactionSyncFailure>(
            TransactionSyncBusyFailure(),
          ),
          retryable: false,
        );
      }
      final initialized = await writer.create(
        params.descriptor.key,
        expectedGeneration: params.generation,
        existingOnly: true,
      );
      if (initialized case Err(:final failure)) {
        return SyncPassOutcome(
          Err<SyncCompletion, TransactionSyncFailure>(failure),
          retryable: false,
        );
      }
    }
    final operation = _NativeSyncOperation(params);
    final result = await writer.sync(
      params.descriptor.key,
      expectedGeneration: params.generation,
      operation: operation,
      reconcile: !params.headless,
      preflight: params.allowInitialScan
          ? null
          : () => checkInitialScan(params),
    );
    return switch (result) {
      Err(:final failure) => SyncPassOutcome(
        Err<SyncCompletion, TransactionSyncFailure>(failure),
        retryable: false,
      ),
      Ok(:final value) => SyncPassOutcome(
        operation.result?.map(
              (completion) => completion.committed(value.revision),
            ) ??
            const Err<SyncCompletion, TransactionSyncFailure>(
              TransactionSyncStorageFailure(),
            ),
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
  Result<SyncCompletion, TransactionSyncFailure>? result;
  String? cacheDiagnostics;
  _NativeSyncOperation(this.params);
  @override
  Future<Result<void, TransactionSyncFailure>> execute(
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
