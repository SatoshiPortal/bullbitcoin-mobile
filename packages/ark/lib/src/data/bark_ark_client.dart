import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../ark.dart';
import '../domain/ark_execution_policy.dart';
import '../domain/ark_board_abandonment_port.dart';
import '../domain/ark_exit_observer_port.dart';
import '../domain/ark_renewal_batches.dart';
import 'ark_chain_preflight.dart';
import 'ark_claim_delivery.dart';
import 'ark_codec.dart';
import 'ark_native_session.dart';
import 'ark_store.dart';
import 'ark_saved_claim.dart';
import 'ark_writer_lock.dart';

/// The writer and immutable projection reader. No command owns source-wallet
/// keys, source locks or host signing/broadcast authority.
final class BarkArkClient implements ArkClient {
  final String storagePath;
  final ArkChildProviderPort childProvider;
  final ArkTransactionVerifierPort transactionVerifier;
  final ArkExecutionPolicyPort executionPolicy;
  final ArkExecutionMode executionMode;
  final ArkStageBudget stageBudget;
  final ArkBoardAbandonmentPort? boardAbandonment;
  final ArkExitObserverPort? exitObserver;
  final ArkNativeOpener opener;
  final String nativeVersion;
  final ArkChainPreflight preflight;
  final DateTime Function() now;
  final HttpArkClaimDelivery claimDelivery;
  final Set<Future<Object?>> _inflight = {};
  final Map<String, StreamController<Result<ArkSnapshot, ArkWalletFailure>>>
  _changes = {};
  bool _closing = false;

  BarkArkClient({
    required this.storagePath,
    required this.childProvider,
    required this.transactionVerifier,
    required this.executionPolicy,
    required this.executionMode,
    required this.stageBudget,
    required this.opener,
    required this.preflight,
    this.nativeVersion = 'scuttle-2ad259dc',
    this.boardAbandonment,
    this.exitObserver,
    DateTime Function()? clock,
    this.claimDelivery = const HttpArkClaimDelivery(),
  }) : now = clock ?? DateTime.now;

  bool _mayRun(ArkAccountId id) =>
      !_closing &&
      stageBudget.mayAdmitNextStage &&
      executionPolicy.mayRun(id, executionMode);
  Future<Result<T, ArkWalletFailure>> _track<T>(
    Future<Result<T, ArkWalletFailure>> Function() action,
  ) {
    if (_closing) {
      return Future.value(
        const Err(ArkUnavailableFailure(ArkFailureReason.closed)),
      );
    }
    late Future<Result<T, ArkWalletFailure>> task;
    task = Future.sync(action).whenComplete(() => _inflight.remove(task));
    _inflight.add(task);
    return task;
  }

  Future<Result<T, ArkWalletFailure>> _exclusive<T>(
    ArkAccountId account,
    Future<Result<T, ArkWalletFailure>> Function(ArkStore store, String path)
    action, {
    bool create = false,
  }) => _track(() async {
    if (!_mayRun(account)) {
      return const Err(ArkUnavailableFailure(ArkFailureReason.budgetExhausted));
    }
    if (create && executionMode != ArkExecutionMode.foreground) {
      return const Err(
        ArkUnavailableFailure(ArkFailureReason.storeIncompatible),
      );
    }
    final root = Directory(storagePath);
    if (!root.existsSync() && !create) {
      return const Err(ArkUnavailableFailure(ArkFailureReason.accountMissing));
    }
    final lifecycle = ArkWriterLock.acquire(
      '$storagePath/lifecycle.sqlite',
      existingOnly: executionMode == ArkExecutionMode.backgroundExisting,
    );
    if (lifecycle case Err(:final failure)) return Err(failure);
    final lifecycleLock =
        (lifecycle as Ok<ArkWriterLock, ArkWalletFailure>).value;
    ArkStore? store;
    ArkWriterLock? lock;
    try {
      final path = ArkStore.accountPath(storagePath, account);
      final admission = ArkWriterLock.acquire(
        '$path/writer.sqlite',
        existingOnly: !create,
      );
      if (admission case Err(:final failure)) return Err(failure);
      lock = (admission as Ok<ArkWriterLock, ArkWalletFailure>).value;
      final metadata = File('$path/state.sqlite');
      final native = Directory('$path/native');
      if (create && !metadata.existsSync() && native.existsSync()) {
        return const Err(ArkRecoveryRequiredFailure());
      }
      store = ArkStore.open(metadata.path, create: create);
      return await action(store, path);
    } on ArkBoundaryException catch (error) {
      return Err(error.failure);
    } on ArkStageDeferred {
      return const Err(ArkUnavailableFailure(ArkFailureReason.budgetExhausted));
    } on SqliteException {
      return const Err(ArkStorageFailure());
    } on FileSystemException {
      return const Err(ArkStorageFailure());
    } on FormatException {
      return const Err(ArkStorageFailure(ArkFailureReason.storeIncompatible));
    } catch (error) {
      if (error is Error) rethrow;
      // Native ErrorException.inner has no useful text. Never parse/log it.
      return const Err(ArkNativeFailure());
    } finally {
      try {
        store?.close();
      } finally {
        try {
          lock?.release();
        } finally {
          lifecycleLock.release();
        }
      }
    }
  });

  @override
  Future<Result<ArkSnapshot, ArkWalletFailure>> create(
    ArkAccountConfig config,
  ) => _exclusive(config.id, (store, path) async {
    final previous = store.get('config');
    if (previous != null &&
        jsonEncode(previous) != jsonEncode(configToJson(config))) {
      return const Err(ArkValidationFailure(ArkFailureReason.identityMismatch));
    }
    if (previous == null) {
      store.put('config', configToJson(config));
      store.put('lifecycle', {'state': 'creating', 'phase': 'not-opened'});
    }
    return _session(store, path, config.id, (session, source, stages) async {
      if (store.get('lifecycle')?['state'] != 'ready') {
        await session.synchronizeStage('initial-scan');
      }
      await _connectServer(session);
      final snapshot = await _observe(store, session, config.id, source);
      store.put('lifecycle', {
        'state': 'ready',
        'nativeVersion': nativeVersion,
      });
      return Ok(snapshot);
    }, allowCreate: store.get('lifecycle')?['state'] == 'creating');
  }, create: true);

  @override
  Future<Result<ArkSnapshot, ArkWalletFailure>> read(
    ArkAccountId account,
  ) => _track(() async {
    final path = ArkStore.accountPath(storagePath, account);
    ArkStore? store;
    try {
      store = ArkStore.open(
        '$path/state.sqlite',
        create: false,
        readOnly: true,
      );
      final snapshot = store.snapshot;
      if (snapshot == null) {
        return const Err(
          ArkUnavailableFailure(ArkFailureReason.accountMissing),
        );
      }
      // Stale after elapsed time, but no native opener for projection reads.
      return Ok(
        copySnapshot(
          snapshot,
          operations: await _verifiedOperations(store, account),
          stale:
              snapshot.stale ||
              _SyncFailures.load(store, account).causes.isNotEmpty ||
              now().difference(snapshot.observedAt) >
                  const Duration(minutes: 5),
        ),
      );
    } on ArkBoundaryException catch (error) {
      return Err(error.failure);
    } on FileSystemException {
      return const Err(ArkUnavailableFailure(ArkFailureReason.accountMissing));
    } catch (error) {
      if (error is Error) rethrow;
      return const Err(ArkStorageFailure());
    } finally {
      store?.close();
    }
  });

  bool _hasClaimToObserve(ArkSnapshot snapshot) => snapshot.exitDetails.any(
    (exit) =>
        exit.status == ArkExitStatus.submitted ||
        (exit.status == ArkExitStatus.claimable &&
            snapshot.operations.any(
              (operation) =>
                  operation.kind == ArkOperationKind.claim &&
                  (operation.status == ArkOperationStatus.admitted ||
                      operation.status == ArkOperationStatus.pending ||
                      operation.status == ArkOperationStatus.succeeded) &&
                  operation.actualIds.contains(exit.id),
            )),
  );

  @override
  Future<Result<ArkOperation?, ArkWalletFailure>> progressStartedExits(
    ArkAccountId account,
  ) async {
    if (executionMode != ArkExecutionMode.foreground) {
      return const Err(ArkUnavailableFailure());
    }
    switch (await read(account)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value)
          when !value.exitDetails.any(
            (exit) => exit.status == ArkExitStatus.pending,
          ):
        if (_hasClaimToObserve(value)) {
          return _exclusive<ArkOperation?>(account, (store, path) async {
            final snapshot = store.snapshot;
            if (snapshot == null ||
                !_hasClaimToObserve(
                  copySnapshot(
                    snapshot,
                    operations: await _verifiedOperations(store, account),
                  ),
                )) {
              return const Ok(null);
            }
            return _session(store, path, account, (session, source, _) async {
              await session.synchronizeStage('exits-observe');
              await _observe(store, session, account, source);
              return const Ok(null);
            });
          });
        }
        return const Ok(null);
      case Ok():
    }
    final progressed = await _exclusive<ArkOperation?>(account, (
      store,
      path,
    ) async {
      final operationId = store.get('initial-exit-start')?['operation'];
      if (operationId is! String) return const Ok(null);
      final record = store.operation(operationId);
      final quote = record == null ? null : store.quote(record.binding);
      final rate = quote?.feeRate;
      if (record == null || quote == null || rate == null) {
        return const Err(ArkStorageFailure());
      }
      if (record.operation.status != ArkOperationStatus.pending &&
          record.operation.status != ArkOperationStatus.succeeded) {
        return Err(ArkOutcomeUnknownFailure(operationId));
      }
      return _session(store, path, account, (session, source, _) async {
        if (session is! ArkNativeExitCpfpSession) {
          return const Err(ArkUnavailableFailure());
        }
        final history = store.exitCpfpHistory(operationId);
        for (final child in history) {
          await session.importExitCpfpChange(child);
        }
        await session.synchronizeStage('exits-observe');
        final due = await session.dueExitCpfp(record.operation.actualIds);
        for (final step in due) {
          final saved = store.exitCpfpEvidence(
            exitOperationId: operationId,
            parentTxid: step.parentTxid,
          );
          if (saved != null) {
            await session.deliverExitCpfp(step, saved);
            continue;
          }
          final remaining =
              quote.fee.value -
              history.fold(BigInt.zero, (sum, child) => sum + child.fee.value);
          if (remaining <= BigInt.zero) {
            return const Err(ArkUnavailableFailure());
          }
          final candidate = await session.prepareExitCpfp(
            step,
            rate,
            Sats(remaining),
          );
          if (!store.admitExitCpfp(
            exitOperationId: operationId,
            vtxoId: step.vtxoId,
            parentTxid: step.parentTxid,
            childTxid: candidate.evidence.txid,
            raw: candidate.evidence.raw,
            fee: candidate.evidence.fee,
            reserveInputs: candidate.reserveInputs,
          )) {
            return const Err(ArkValidationFailure());
          }
          await session.deliverExitCpfp(step, candidate.evidence);
          break; // Its change is only reusable after confirmation.
        }
        await _observe(store, session, account, source);
        return Ok(record.operation);
      }, requiredSource: quote.chainSource);
    });
    if (progressed is! Ok<ArkOperation?, ArkWalletFailure> ||
        progressed.value != null) {
      return progressed;
    }
    // Existing sessions without a journal use the ordinary quote path.
    return _quoteAndConfirm(
      account,
      ArkQuoteRequest.exitProgress(),
      // Nothing to broadcast yet: the last transaction is still confirming.
      skip: (reviewed) => reviewed.fee.value == BigInt.zero,
    );
  }

  /// Quotes [request] and confirms that exact quote, for work the user
  /// authorized earlier and no one reviews now. A block landing between the
  /// two makes the quote stale; then it is quoted afresh, a few times, under
  /// the same checks. Null when [skip] says there is nothing to do.
  Future<Result<ArkOperation?, ArkWalletFailure>> _quoteAndConfirm(
    ArkAccountId account,
    ArkQuoteRequest request, {
    bool Function(ArkQuote reviewed)? skip,
  }) async {
    ArkWalletFailure failure = const ArkStaleQuoteFailure();
    for (var attempt = 0; attempt < 3; attempt++) {
      switch (await quote(account, request)) {
        case Err(failure: ArkStaleQuoteFailure()):
          continue;
        case Err(failure: final refused):
          return Err(refused);
        case Ok(value: final reviewed) when skip?.call(reviewed) ?? false:
          return const Ok(null);
        case Ok(value: final reviewed):
          switch (await submit(
            account,
            ArkSubmission.confirmQuote(
              quoteId: reviewed.id,
              operationId: _id(),
            ),
          )) {
            case Ok(:final value):
              return Ok(value);
            case Err(failure: final stale && ArkStaleQuoteFailure()):
              failure = stale;
            case Err(failure: final refused):
              return Err(refused);
          }
      }
    }
    return Err(failure);
  }

  @override
  Future<Result<List<ArkOperation>, ArkWalletFailure>> claimAuthorized(
    ArkAccountId account,
  ) async {
    if (executionMode != ArkExecutionMode.foreground) {
      return const Err(ArkUnavailableFailure());
    }
    final List<String> claimable;
    final Set<String> unrolling;
    switch (await read(account)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        claimable = [
          for (final exit in value.exitDetails)
            if (exit.status == ArkExitStatus.claimable) exit.id,
        ];
        unrolling = {
          for (final exit in value.exitDetails)
            if (exit.status == ArkExitStatus.pending) exit.id,
        };
    }
    if (claimable.isEmpty) return const Ok([]);
    final path = ArkStore.accountPath(storagePath, account);
    final List<
      ({String destination, Sats remainingFee, List<String> remainingIds})
    >
    allowances;
    ArkStore? store;
    try {
      store = ArkStore.open(
        '$path/state.sqlite',
        create: false,
        readOnly: true,
      );
      allowances = store.claimAllowances();
    } on FileSystemException {
      return const Err(ArkUnavailableFailure(ArkFailureReason.accountMissing));
    } catch (error) {
      if (error is Error) rethrow;
      return const Err(ArkStorageFailure());
    } finally {
      store?.close();
    }
    final admitted = <ArkOperation>[];
    ArkWalletFailure? failed;
    for (final allowance in allowances) {
      // VTXOs exited together are claimed together, in one transaction with
      // one fee: wait while any of them is still on its way. One that can no
      // longer finish (swept, spent) is not waited for.
      if (allowance.remainingIds.any(unrolling.contains)) continue;
      final ids = [
        for (final id in allowance.remainingIds)
          if (claimable.contains(id)) id,
      ];
      if (ids.isEmpty || allowance.remainingFee.value <= BigInt.zero) continue;
      // The ordinary quote and confirm path: every check a reviewed claim
      // passes, against the authority recorded when the exit started.
      switch (await _quoteAndConfirm(
        account,
        ArkQuoteRequest.claim(
          ids: ids,
          destination: allowance.destination,
          maxFee: allowance.remainingFee,
        ),
      )) {
        case Ok(:final value?):
          admitted.add(value);
        case Ok():
          break;
        case Err(:final failure):
          failed ??= failure;
      }
    }
    if (admitted.isEmpty && failed != null) return Err(failed);
    return Ok(admitted);
  }

  @override
  Stream<Result<ArkSnapshot, ArkWalletFailure>> watch(ArkAccountId account) {
    final controller = _changes.putIfAbsent(
      account.canonical,
      () => StreamController.broadcast(),
    );
    return Stream.multi((events) {
      var revision = -1;
      void emit(Result<ArkSnapshot, ArkWalletFailure> value) {
        if (value case Ok(:final value)) {
          if (value.revision < revision) return;
          revision = value.revision;
        }
        events.add(value);
      }

      final subscription = controller.stream.listen(emit, onDone: events.close);
      events.onCancel = subscription.cancel;
      read(account).then(emit, onError: events.addError);
    });
  }

  Future<List<ArkOperation>> _verifiedOperations(
    ArkStore store,
    ArkAccountId account,
  ) async => [
    for (final operation in store.operations)
      await _verifiedOperation(store, account, operation),
  ];

  Future<ArkOperation> _verifiedOperation(
    ArkStore store,
    ArkAccountId account,
    ArkOperation operation,
  ) async {
    final record = store.operation(operation.id);
    final evidence = record?.evidence;
    if (evidence?['raw'] == null) {
      if (operation.claimRecovery != null) {
        throw const ArkBoundaryException(ArkValidationFailure());
      }
      return operation;
    }
    final quote = record == null ? null : store.quote(record.binding);
    final config = store.get('config');
    if (quote == null || config == null || evidence == null) {
      throw const ArkBoundaryException(ArkValidationFailure());
    }
    final saved = await ArkSavedClaim.inspect(
      account: account,
      config: configFromJson(config),
      quote: quote,
      operation: operation,
      evidence: evidence,
      verifier: transactionVerifier,
    );
    return ArkOperation(
      id: operation.id,
      kind: operation.kind,
      status: operation.status,
      chainSource: operation.chainSource,
      configGeneration: operation.configGeneration,
      nativeReference: operation.nativeReference,
      actualIds: operation.actualIds,
      skippedIds: operation.skippedIds,
      boardFunding: operation.boardFunding,
      claimRecovery: saved.summary,
    );
  }

  Future<Result<T, ArkWalletFailure>> _session<T>(
    ArkStore store,
    String path,
    ArkAccountId account,
    Future<Result<T, ArkWalletFailure>> Function(ArkNativeSession, Uri, _Stages)
    action, {
    bool allowCreate = false,
    Uri? requiredSource,
  }) async {
    final stored = store.get('config');
    if (stored == null) {
      return const Err(ArkUnavailableFailure(ArkFailureReason.accountMissing));
    }
    final config = configFromJson(stored);
    if (config.id != account) {
      return const Err(ArkValidationFailure(ArkFailureReason.identityMismatch));
    }
    if (executionMode == ArkExecutionMode.backgroundExisting &&
        (store.get('lifecycle')?['state'] != 'ready' ||
            store.get('lifecycle')?['nativeVersion'] != nativeVersion)) {
      return const Err(
        ArkUnavailableFailure(ArkFailureReason.storeIncompatible),
      );
    }
    final unfinished = store.operations
        .where(
          (o) =>
              o.status != ArkOperationStatus.succeeded &&
              o.status != ArkOperationStatus.failed,
        )
        .toList();
    final pinnedSources = unfinished.map((o) => o.chainSource).toSet();
    if (pinnedSources.length > 1 ||
        (requiredSource != null &&
            pinnedSources.any((s) => s != requiredSource))) {
      return const Err(
        ArkUnavailableFailure(ArkFailureReason.chainUnreachable),
      );
    }
    final pinned =
        requiredSource ?? (pinnedSources.isEmpty ? null : pinnedSources.single);
    if (!_mayRun(account)) {
      return const Err(ArkUnavailableFailure(ArkFailureReason.budgetExhausted));
    }
    final selected = await preflight.select(
      config,
      requiredSource: pinned,
      minimumTip: store.snapshot?.tipHeight,
    );
    if (selected case Err(:final failure)) return Err(failure);
    final source = (selected as Ok<Uri, ArkWalletFailure>).value;
    if (source != config.primaryEsploraUrl &&
        source != config.fallbackEsploraUrl) {
      return const Err(ArkValidationFailure(ArkFailureReason.identityMismatch));
    }
    final datadir = '$path/native';
    final exists = opener.datadirExists(datadir);
    if (!exists && !allowCreate) return const Err(ArkRecoveryRequiredFailure());
    final stages = _Stages(() => _mayRun(account));
    return childProvider.withChild(account, (mnemonic, fingerprint) async {
      ArkNativeSession? session;
      try {
        if (store.get('recovery') == null) {
          store.put('recovery', {
            'status': ArkRecoveryStatus.unknown.name,
            'interrupted': true,
          });
        }
        final priorLifecycle = store.get('lifecycle');
        final priorPhase = priorLifecycle?['phase'];
        final expectedNative =
            store.get('native-identity') != null ||
            priorLifecycle?['state'] == 'ready' ||
            priorPhase != 'not-opened';
        session = await opener.open(
          config: config,
          datadir: datadir,
          mnemonic: mnemonic,
          childFingerprint: fingerprint,
          chainSource: source,
          create: allowCreate,
          expectedFingerprint:
              store.get('native-identity')?['fingerprint'] as String?,
          nativePreviouslyAdmitted: expectedNative,
          onNativeAdmission: () {
            final lifecycle = store.get('lifecycle');
            if (lifecycle != null && lifecycle['state'] == 'creating') {
              lifecycle['phase'] = 'native-admitted';
              store.put('lifecycle', lifecycle);
            }
          },
          onOnchainOpened: () {
            final state = store.get('lifecycle') ?? <String, Object?>{};
            if (state['state'] == 'creating') {
              state['phase'] = 'onchain-opened';
              store.put('lifecycle', state);
            }
          },
          onOpened: (recovery, fingerprint) {
            final previous = store.get('native-identity');
            if (previous != null && previous['fingerprint'] != fingerprint) {
              throw const ArkBoundaryException(
                ArkValidationFailure(ArkFailureReason.identityMismatch),
              );
            }
            store.put('native-identity', {'fingerprint': fingerprint});
            if (recovery != ArkRecoveryStatus.notRun) {
              store.put('recovery', {'status': recovery.name});
            } else if (store.get('recovery') == null) {
              store.put('recovery', {
                'status': ArkRecoveryStatus.unknown.name,
                'interrupted': true,
              });
            }
            final state = store.get('lifecycle') ?? <String, Object?>{};
            if (state['state'] == 'creating') {
              state['phase'] = 'ark-opened';
              store.put('lifecycle', state);
            }
          },
          stages: stages,
        );
        return await action(session, source, stages);
      } finally {
        await session?.close();
      }
    });
  }

  ArkRecoveryStatus _storedRecovery(ArkStore store, ArkSnapshot? previous) {
    final name = store.get('recovery')?['status'];
    return name is String
        ? ArkRecoveryStatus.values.byName(name)
        : previous?.recovery ?? ArkRecoveryStatus.unknown;
  }

  Future<ArkSnapshot> _classifyAbandonedBoards(
    ArkStore store,
    ArkSnapshot snapshot,
    Map<String, ArkNeverSignedBoard?> proofs, {
    Set<String>? nativeIds,
  }) async {
    final authority = boardAbandonment;
    if (authority == null) return snapshot;
    final native = nativeIds ?? snapshot.vtxos.map((v) => v.id).toSet();
    final candidates = <String>{};
    // Bark lists a pending Board's VTXO as unknown or, in newer versions,
    // as locked while it waits for the funding transaction.
    for (final vtxo in snapshot.vtxos.where(
      (v) => v.state == ArkVtxoState.unknown || v.state == ArkVtxoState.locked,
    )) {
      final boards = snapshot.pendingBoards
          .where((b) => b.vtxoId == vtxo.id)
          .toList();
      if (boards.length != 1 ||
          snapshot.vtxos.where((v) => v.id == vtxo.id).length != 1) {
        continue;
      }
      final board = boards.single;
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(board.fundingTxid) ||
          snapshot.pendingBoards
                  .where((b) => b.fundingTxid == board.fundingTxid)
                  .length !=
              1 ||
          board.amount != vtxo.amount) {
        continue;
      }
      final operations = snapshot.operations
          .where(
            (o) =>
                o.kind == ArkOperationKind.board &&
                o.nativeReference == board.fundingTxid,
          )
          .toList();
      if (operations.length != 1) continue;
      final operation = operations.single;
      final tuple = operation.boardFunding;
      final record = store.operation(operation.id);
      final quote = record == null ? null : store.quote(record.binding);
      if (tuple == null ||
          quote == null ||
          quote.account != snapshot.account ||
          quote.kind != ArkOperationKind.board) {
        continue;
      }
      if (!proofs.containsKey(operation.id)) {
        if (!_mayRun(snapshot.account)) continue;
        proofs[operation.id] = switch (await authority.readNeverSigned(
          account: snapshot.account,
          operationId: operation.id,
          fundingTxid: board.fundingTxid,
        )) {
          Ok(:final value) => value,
          Err() => null,
        };
      }
      final proof = proofs[operation.id];
      if (proof == null ||
          proof.account != snapshot.account ||
          proof.operationId != operation.id ||
          proof.fundingTxid != board.fundingTxid ||
          proof.address != tuple.address ||
          proof.keypairIndex != tuple.keypairIndex ||
          proof.expiryHeight != tuple.expiryHeight ||
          proof.expiryHeight != vtxo.expiryHeight ||
          (board.expiryHeight != null &&
              board.expiryHeight != proof.expiryHeight) ||
          proof.grossAmount != quote.amount ||
          proof.netAmount != quote.net ||
          proof.netAmount != board.amount ||
          proof.netAmount.value <= BigInt.zero ||
          quote.amount.value - quote.fee.value != quote.net.value) {
        continue;
      }
      candidates.add(vtxo.id);
    }
    if (candidates.isEmpty) return snapshot;
    // Do not subtract a Board value from unrelated Lightning/round pending funds.
    final boardBalance = snapshot.pendingBoardBalance;
    final pending = snapshot.pending;
    final nativeBoardRows = snapshot.pendingBoards.where(
      (b) =>
          native.contains(b.vtxoId) &&
          snapshot.vtxos.any(
            (v) =>
                v.id == b.vtxoId &&
                (v.state == ArkVtxoState.unknown ||
                    v.state == ArkVtxoState.locked),
          ),
    );
    final counted = nativeBoardRows.fold<BigInt>(
      BigInt.zero,
      (sum, b) => sum + b.amount.value,
    );
    if (boardBalance == null ||
        pending == null ||
        (boardBalance.value != BigInt.zero && counted != boardBalance.value) ||
        pending.value < boardBalance.value) {
      return snapshot;
    }
    final removed = boardBalance.value == BigInt.zero
        ? BigInt.zero
        : nativeBoardRows
              .where((b) => candidates.contains(b.vtxoId))
              .fold<BigInt>(BigInt.zero, (sum, b) => sum + b.amount.value);
    return copySnapshot(
      snapshot,
      pending: Sats(pending.value - removed),
      pendingBoardBalance: Sats(boardBalance.value - removed),
      vtxos: [
        for (final v in snapshot.vtxos)
          if (candidates.contains(v.id))
            ArkVtxo(
              id: v.id,
              amount: v.amount,
              expiryHeight: v.expiryHeight,
              state: ArkVtxoState.abandonedBoard,
              anchor: v.anchor,
              pendingRound: v.pendingRound,
            )
          else
            v,
      ],
    );
  }

  Future<ArkSnapshot> _observe(
    ArkStore store,
    ArkNativeSession session,
    ArkAccountId account,
    Uri source, {
    bool commit = true,
    int? revision,
    void Function(bool)? onNativeStaleness,
    bool authoritativePass = true,
    _SyncFailures? syncFailures,
    Set<String> successfulStages = const {},
  }) async {
    final previous = store.snapshot;
    var observed = await session.observe(
      account: account,
      revision: revision ?? (previous?.revision ?? 0) + 1,
      now: now().toUtc(),
      chainSource: source,
      operations: await _verifiedOperations(store, account),
      previousRecovery: _storedRecovery(store, previous),
    );
    onNativeStaleness?.call(observed.stale);
    // Without a live server connection Bark reports no server information.
    // Keep the last observed one instead of erasing it from the snapshot.
    if ((observed.serverInfo, previous?.serverInfo) case (null, final kept?)) {
      observed = copySnapshot(observed, serverInfo: kept);
    }
    var reserveAddress = store.get('reserve-address')?['address'] as String?;
    if (reserveAddress == null &&
        executionMode == ArkExecutionMode.foreground) {
      reserveAddress = await session.reserveAddress();
      store.put('reserve-address', {'address': reserveAddress});
    }
    observed = copySnapshot(observed, reserveAddress: reserveAddress);
    final proofs = <String, ArkNeverSignedBoard?>{};
    final nativeIds = observed.vtxos
        .where(
          (v) =>
              v.state == ArkVtxoState.unknown || v.state == ArkVtxoState.locked,
        )
        .map((v) => v.id)
        .toSet();
    observed = await _classifyAbandonedBoards(store, observed, proofs);
    final barriers = syncFailures ?? _SyncFailures.load(store, account);
    barriers.resolve({
      ...successfulStages,
      if (syncFailures != null) 'observe',
    }, source);
    if (barriers.candidate.isNotEmpty) {
      observed = copySnapshot(observed, stale: true);
    }
    final previousTip = previous?.tipHeight;
    final nextTip = observed.tipHeight;
    if (previousTip != null && (nextTip == null || nextTip < previousTip)) {
      throw const ArkBoundaryException(
        ArkUnavailableFailure(ArkFailureReason.chainUnreachable),
      );
    }
    final inventory =
        store.get('inventory-obligations') ?? store.get('complete-inventory');
    final baseline = inventory == null
        ? previous?.vtxos ?? const <ArkVtxo>[]
        : maps(inventory['vtxos']).map(vtxoFromJson).toList();
    final authoritative =
        authoritativePass &&
        !observed.stale &&
        observed.vtxoInventoryComplete &&
        observed.recovery == ArkRecoveryStatus.complete &&
        observed.tipHeight != null &&
        observed.vtxos.every((v) => v.state != ArkVtxoState.unknown);
    bool provenSpent(String id) {
      if (!authoritative) {
        return false;
      }
      if (observed.exitDetails.any(
        (exit) =>
            exit.id == id &&
            exit.status == ArkExitStatus.claimed &&
            exit.claimTxid != null &&
            RegExp(r'^[0-9a-f]{64}$').hasMatch(exit.claimTxid ?? ''),
      )) {
        return true;
      }
      return observed.movements.any(
        (movement) =>
            terminalMovementRetires(movement, id, observed.vtxos) ||
            (movement.status == ArkMovementStatus.successful &&
                movement.inputVtxoIds.contains(id) &&
                (movement.kind == ArkMovementKind.renewal
                    ? observed.renewal != ArkRenewalStatus.delegated &&
                          observed.renewal != ArkRenewalStatus.failed &&
                          observed.renewal != ArkRenewalStatus.unknown &&
                          movement.outputVtxoIds.isNotEmpty &&
                          movement.outputVtxoIds.every(
                            (output) => observed.vtxos.any(
                              (v) =>
                                  v.id == output &&
                                  v.eligibleAt(observed.tipHeight ?? 0),
                            ),
                          )
                    : movement.kind == ArkMovementKind.payment &&
                          movement.outputVtxoIds.every(
                            (output) => observed.vtxos.any(
                              (v) =>
                                  v.id == output &&
                                  v.eligibleAt(observed.tipHeight ?? 0),
                            ),
                          ))),
      );
    }

    final known = {for (final v in baseline) v.id: v};
    for (final v in observed.vtxos.where(
      (v) => v.state != ArkVtxoState.spent,
    )) {
      known.putIfAbsent(v.id, () => v);
    }
    final unresolved = <ArkVtxo>[];
    final retainedAbandoned = <ArkVtxo>[];
    for (final old in known.values.where(
      (v) => v.state != ArkVtxoState.spent,
    )) {
      final current = observed.vtxos.where((v) => v.id == old.id).firstOrNull;
      if ((current == null || current.state == ArkVtxoState.spent) &&
          old.state == ArkVtxoState.abandonedBoard &&
          !observed.pendingBoards.any((b) => b.vtxoId == old.id)) {
        retainedAbandoned.add(old);
      } else if ((current == null || current.state == ArkVtxoState.spent) &&
          !provenSpent(old.id)) {
        unresolved.add(
          ArkVtxo(
            id: old.id,
            amount: old.amount,
            expiryHeight: old.expiryHeight,
            state: ArkVtxoState.unknown,
            anchor: old.anchor,
            pendingRound: old.pendingRound,
          ),
        );
      }
    }
    if (unresolved.isNotEmpty || retainedAbandoned.isNotEmpty) {
      final retained = [...unresolved, ...retainedAbandoned];
      final ids = retained.map((v) => v.id).toSet();
      observed = copySnapshot(
        observed,
        vtxos: [
          ...observed.vtxos.where((v) => !ids.contains(v.id)),
          ...retained,
        ],
      );
      observed = await _classifyAbandonedBoards(
        store,
        observed,
        proofs,
        nativeIds: nativeIds,
      );
    }
    if (observed.vtxos.any((v) => v.state == ArkVtxoState.unknown)) {
      observed = copySnapshot(
        observed,
        stale: true,
        vtxoCompleteness: ArkSectionCompleteness.incomplete,
      );
    }
    final pinned = store.get('server');
    final key = observed.serverInfo?.publicKey;
    if (pinned != null && key != null && pinned['key'] != key) {
      throw const ArkBoundaryException(
        ArkValidationFailure(ArkFailureReason.identityMismatch),
      );
    }
    if (pinned == null && key != null) store.put('server', {'key': key});
    if (commit) _commitObservation(store, observed);
    return observed;
  }

  /// Bark connects to the server lazily and reports no server information
  /// until it has. A new account has no earlier information to keep, so its
  /// first observation connects; an unreachable server leaves it without.
  Future<void> _connectServer(ArkNativeSession session) async {
    try {
      await session.synchronizeStage('server');
    } on ArkStageDeferred {
      rethrow;
    } catch (error) {
      if (error is Error) rethrow;
    }
  }

  void _commitObservation(
    ArkStore store,
    ArkSnapshot snapshot, {
    Map<String, Object?>? syncFailures,
    List<ArkOperation> settledOperations = const [],
  }) {
    store.commitObservation(
      snapshot,
      syncFailures: syncFailures,
      settledOperations: settledOperations,
    );
    _changes[snapshot.account.canonical]?.add(Ok(snapshot));
  }

  @override
  Future<Result<ArkPassOutcome, ArkWalletFailure>> synchronize(
    ArkAccountId account, {
    required bool renew,
  }) => _exclusive(
    account,
    (store, path) => _session(store, path, account, (
      session,
      source,
      stages,
    ) async {
      final failed = <String>[];
      final completed = <ArkStage>{};
      final failedKinds = <ArkStage>{};
      final rounds = <String>[];
      final barriers = _SyncFailures.load(store, account);
      final successfulStages = <String>{};
      void record(String stage, bool failedStage) => barriers.record(
        store,
        stage,
        failedStage,
        source,
        (store.snapshot?.revision ?? 0) + 1,
      );
      for (final entry in {
        'ark': ArkStage.ark,
        'lightning': ArkStage.lightning,
        'rounds': ArkStage.rounds,
        'boards': ArkStage.boards,
        if (executionMode == ArkExecutionMode.foreground &&
            session is ArkNativeOffboardSession)
          'offboards': ArkStage.onchain,
        'server': ArkStage.server,
        'onchain': ArkStage.onchain,
        'exits-observe': ArkStage.exits,
      }.entries) {
        if (!_mayRun(account)) {
          record(entry.key, false);
          failed.add('deferred');
          break;
        }
        try {
          await session.synchronizeStage(entry.key);
          successfulStages.add(entry.key);
          completed.add(entry.value);
        } on ArkStageDeferred {
          record(entry.key, false);
          failed.add('deferred');
          break;
        } catch (error) {
          if (error is Error) rethrow;
          record(entry.key, true);
          failed.add(entry.key);
          failedKinds.add(entry.value);
        }
      }
      for (final operation in store.operations) {
        if (!_mayRun(account)) break;
        if (operation.status == ArkOperationStatus.succeeded ||
            operation.status == ArkOperationStatus.failed) {
          continue;
        }
        try {
          final reconciled = await session.reconcile(operation);
          if (reconciled != null) {
            final record = store.operation(operation.id);
            if (record != null) store.saveOperation(reconciled, record.binding);
          }
        } catch (error) {
          if (error is Error) rethrow;
          failed.add('reconciliation');
        }
      }
      ArkSnapshot snapshot;
      try {
        snapshot = await _observe(
          store,
          session,
          account,
          source,
          commit: false,
          authoritativePass: failed.isEmpty,
          syncFailures: barriers,
          successfulStages: successfulStages,
        );
        completed.add(ArkStage.vtxos);
      } on ArkStageDeferred {
        record('observe', false);
        final previous = store.snapshot;
        if (previous == null) {
          return const Err(
            ArkUnavailableFailure(ArkFailureReason.budgetExhausted),
          );
        }
        snapshot = copySnapshot(
          previous,
          stale: true,
          operations: store.operations,
          vtxoCompleteness: ArkSectionCompleteness.incomplete,
        );
        failed.add('deferred');
        failedKinds.add(ArkStage.vtxos);
      } catch (error) {
        if (error is Error) rethrow;
        record('observe', true);
        final previous = store.snapshot;
        if (previous != null) {
          _commitObservation(
            store,
            copySnapshot(previous, stale: true),
            syncFailures: barriers.encode(barriers.causes),
          );
        }
        rethrow;
      }
      if (failed.isNotEmpty) snapshot = copySnapshot(snapshot, stale: true);
      if (renew &&
          _mayRun(account) &&
          completed.contains(ArkStage.vtxos) &&
          snapshot.vtxoInventoryComplete &&
          !snapshot.stale &&
          snapshot.recovery == ArkRecoveryStatus.complete) {
        final tip = snapshot.tipHeight;
        if (tip != null) {
          try {
            final candidates = (await session.renewalCandidates()).toSet();
            final held = store.operations
                .where(
                  (o) =>
                      o.status == ArkOperationStatus.pending ||
                      o.status == ArkOperationStatus.admitted ||
                      o.status == ArkOperationStatus.outcomeUnknown ||
                      o.status == ArkOperationStatus.conflicted,
                )
                .expand((o) => o.actualIds)
                .toSet();
            final eligible = snapshot.vtxos
                .where(
                  (v) =>
                      candidates.contains(v.id) &&
                      v.eligibleAt(tip) &&
                      !held.contains(v.id),
                )
                .toList();
            final batches = partitionArkRenewalBatches(
              eligible,
              snapshot.serverInfo?.maximumVtxo,
            );
            if (batches case Err(:final failure)) {
              throw ArkBoundaryException(failure);
            }
            for (final batch
                in (batches as Ok<List<List<ArkVtxo>>, ArkWalletFailure>)
                    .value) {
              if (!_mayRun(account)) {
                failed.add('deferred');
                break;
              }
              final quote = await session.estimate(
                snapshot: snapshot,
                request: ArkQuoteRequest.renewal(
                  ids: batch.map((v) => v.id).toList(),
                ),
                id: _id(),
                chainSource: source,
                configGeneration: 1,
                now: now(),
              );
              store.saveQuote(quote);
              final operation = await _executeQuote(
                store,
                session,
                quote,
                _id(),
              );
              rounds.add(operation.nativeReference ?? operation.id);
              completed.add(ArkStage.renewal);
              snapshot = copySnapshot(
                snapshot,
                operations: store.operations,
                renewal: ArkRenewalStatus.delegated,
              );
              // Ambiguity stops this pass; never consume other inputs blindly.
              if (operation.status == ArkOperationStatus.outcomeUnknown) {
                failed.add('renewal');
                failedKinds.add(ArkStage.renewal);
                break;
              }
            }
          } catch (error) {
            if (error is Error) rethrow;
            failed.add('renewal');
            failedKinds.add(ArkStage.renewal);
          }
        }
      }

      if (failed.isNotEmpty || rounds.isNotEmpty) {
        snapshot = copySnapshot(snapshot, stale: true);
      }
      final settled = <ArkOperation>[];
      if (failed.isEmpty &&
          rounds.isEmpty &&
          !snapshot.stale &&
          snapshot.vtxoInventoryComplete &&
          snapshot.tipHeight != null &&
          snapshot.recovery == ArkRecoveryStatus.complete) {
        for (final operation in store.operations) {
          if (operation.status == ArkOperationStatus.outcomeUnknown &&
              (operation.kind == ArkOperationKind.payment ||
                  operation.kind == ArkOperationKind.renewal) &&
              operation.chainSource == source &&
              operation.configGeneration == 1 &&
              operation.actualIds.isNotEmpty &&
              operation.actualIds.every(
                (id) => snapshot.vtxos.any(
                  (v) =>
                      v.id == id &&
                      v.state == ArkVtxoState.spendable &&
                      !v.pendingRound,
                ),
              ) &&
              !snapshot.movements.any(
                (m) => m.inputVtxoIds.any(operation.actualIds.contains),
              )) {
            settled.add(
              operationFromJson({
                ...operationToJson(operation),
                'status': ArkOperationStatus.failed.name,
              }),
            );
          }
        }
      }
      if (settled.isNotEmpty) {
        final byId = {for (final operation in settled) operation.id: operation};
        snapshot = copySnapshot(
          snapshot,
          operations: [
            for (final operation in store.operations)
              byId[operation.id] ?? operation,
          ],
        );
      }
      _commitObservation(
        store,
        snapshot,
        settledOperations: settled,
        syncFailures: barriers.encode(
          failed.isEmpty &&
                  !snapshot.stale &&
                  snapshot.vtxoInventoryComplete &&
                  snapshot.recovery == ArkRecoveryStatus.complete
              ? barriers.candidate
              : barriers.causes,
        ),
      );
      final outcome = ArkPassOutcome(
        snapshot: snapshot,
        failedStages: failed,
        submittedRounds: rounds,
        completedStages: completed,
        failedStageKinds: failedKinds,
      );
      if (executionMode == ArkExecutionMode.backgroundExisting &&
          _mayRun(account)) {
        try {
          await exitObserver?.observe(outcome);
        } on Exception {
          // A notification failure must never invalidate a committed sync.
        }
      }
      return Ok(outcome);
    }),
  );
  @override
  Future<Result<ArkQuote, ArkWalletFailure>> quote(
    ArkAccountId account,
    ArkQuoteRequest request,
  ) => _exclusive(account, (store, path) async {
    if (executionMode != ArkExecutionMode.foreground) {
      return const Err(ArkUnavailableFailure());
    }
    return _session(store, path, account, (session, source, stages) async {
      final liveBoard =
          request is ArkBoardQuoteRequest &&
          session is ArkNativeLiveBoardSession;
      if (request is ArkBoardQuoteRequest &&
          request.anchor != null &&
          !liveBoard) {
        return const Err(ArkUnavailableFailure());
      }
      if (request is ArkBoardQuoteRequest && !liveBoard) {
        await session.synchronizeStage('server');
      }
      final snapshot = await _observe(store, session, account, source);
      if (request is! ArkEmergencyExitQuoteRequest &&
          request is! ArkExitProgressQuoteRequest &&
          request is! ArkClaimQuoteRequest &&
          (snapshot.recovery != ArkRecoveryStatus.complete ||
              (!liveBoard &&
                  (snapshot.stale || !snapshot.vtxoInventoryComplete)))) {
        return const Err(ArkRecoveryRequiredFailure());
      }
      var needsClaimAuthority = false;
      var pricedRequest = request;
      if (request case ArkClaimQuoteRequest(
        :final ids,
        :final destination,
        :final maxFee,
        :final reserveSweepFeeRate,
      )) {
        needsClaimAuthority =
            store.claimAuthority(ids, destination, maxFee) == null;
        if (reserveSweepFeeRate != null &&
            (session is! ArkNativeExitReserveSession || needsClaimAuthority)) {
          return const Err(ArkUnavailableFailure());
        }
        if (session is ArkNativeExitReserveSession &&
            !needsClaimAuthority &&
            reserveSweepFeeRate == null) {
          final exitId = store.get('initial-exit-start')?['operation'];
          final bound = exitId is String ? store.operation(exitId) : null;
          final rate = bound == null
              ? null
              : store.quote(bound.binding)?.feeRate;
          if (rate == null) return const Err(ArkUnavailableFailure());
          pricedRequest = ArkQuoteRequest.claim(
            ids: ids,
            destination: destination,
            maxFee: maxFee,
            reserveSweepFeeRate: rate,
          );
        }
      }
      final quoteId = _id();
      Future<ArkQuote> price() => session.estimate(
        snapshot: snapshot,
        request: pricedRequest,
        id: quoteId,
        chainSource: source,
        configGeneration: 1,
        now: now(),
      );
      var quote = await price();
      if (request case ArkEmergencyExitQuoteRequest(:final reserveFunding)) {
        if (session is ArkNativeExitReserveSession &&
            snapshot.exits == ArkExitStatus.none) {
          final saved = store.initialExitReserve(quote);
          final funding = reserveFunding ?? saved?.funding;
          if (funding != null) {
            final reserveAddress = snapshot.reserveAddress;
            if (reserveAddress == null ||
                reserveAddress.isEmpty ||
                (saved != null && saved.address != reserveAddress) ||
                funding.amount.value < quote.fee.value ||
                !await session.verifyInitialExitReserve(
                  funding,
                  reserveAddress,
                ) ||
                !store.bindInitialExitReserve(
                  quote: quote,
                  reserveAddress: reserveAddress,
                  funding: funding,
                ) ||
                !await session.importInitialExitReserve(
                  funding,
                  reserveAddress,
                )) {
              return const Err(ArkUnavailableFailure());
            }
            quote = await price();
          }
        } else if (reserveFunding != null) {
          return const Err(ArkUnavailableFailure());
        }
      }
      if (liveBoard && quote.boardEvidence == null) {
        return const Err(ArkUnavailableFailure());
      }
      store.saveQuote(quote, claimAuthorityRequired: needsClaimAuthority);
      return Ok(quote);
    });
  });

  @override
  Future<Result<ArkOperation, ArkWalletFailure>> submit(
    ArkAccountId account,
    ArkSubmission submission,
  ) => _exclusive(account, (store, path) async {
    if (submission case ArkRebroadcastClaim()) {
      return _deliverSavedClaim(store, account, submission);
    }
    if (executionMode != ArkExecutionMode.foreground) {
      return const Err(ArkUnavailableFailure());
    }
    final operationId = switch (submission) {
      ArkConfirmQuote(:final operationId) => operationId,
      ArkBoardFunding(:final operationId) => operationId,
      ArkRegisterBoard(:final operationId) => operationId,
      ArkRebroadcastClaim(:final operationId) => operationId,
    };
    final existing = store.operation(operationId);
    final quoteId = switch (submission) {
      ArkConfirmQuote(:final quoteId) => quoteId,
      ArkBoardFunding(:final quoteId) => quoteId,
      ArkRegisterBoard() => existing?.binding,
      ArkRebroadcastClaim() => null,
    };
    if (quoteId == null) return const Err(ArkValidationFailure());
    if (existing != null && existing.binding != quoteId) {
      return const Err(ArkValidationFailure());
    }
    if (submission is! ArkRegisterBoard && existing != null) {
      if (submission is ArkBoardFunding &&
          existing.operation.kind == ArkOperationKind.board &&
          existing.operation.status == ArkOperationStatus.failed &&
          existing.operation.boardFunding == null) {
        return const Err(ArkStaleQuoteFailure());
      }
      return Ok(await _verifiedOperation(store, account, existing.operation));
    }
    if (submission case ArkRegisterBoard()) {
      final registration = existing?.evidence?['registration'];
      if (registration != null) {
        final binding = jsonEncode({
          'psbt': submission.unfinalisedPsbt,
          'index': submission.keypairIndex,
          'expiry': submission.expiryHeight,
        });
        if (registration != binding) return const Err(ArkValidationFailure());
        if (existing case final record?) return Ok(record.operation);
      }
    }

    if (existing == null &&
        store.operations.any(
          (op) => store.operation(op.id)?.binding == quoteId,
        )) {
      return const Err(ArkValidationFailure());
    }
    final quote = store.quote(quoteId);
    if (quote == null ||
        quote.account != account ||
        quote.configGeneration != 1 ||
        !quote.validUntil.isAfter(now())) {
      return const Err(ArkStaleQuoteFailure());
    }
    if (quote.boardEvidence != null &&
        submission is! ArkBoardFunding &&
        submission is! ArkRegisterBoard) {
      return const Err(ArkValidationFailure());
    }
    if (existing == null &&
        store.operations.any(
          (op) =>
              (op.status == ArkOperationStatus.admitted ||
                  op.status == ArkOperationStatus.outcomeUnknown ||
                  op.status == ArkOperationStatus.conflicted ||
                  op.status == ArkOperationStatus.pending) &&
              (op.kind == ArkOperationKind.payment ||
                  op.kind == ArkOperationKind.renewal ||
                  op.kind == ArkOperationKind.claim) &&
              op.actualIds.any(quote.selectedIds.contains) &&
              !(quote.kind == ArkOperationKind.emergencyExit &&
                  op.status == ArkOperationStatus.outcomeUnknown),
        )) {
      return const Err(ArkUnavailableFailure());
    }
    return _session(store, path, account, (session, source, stages) async {
      if (quote.boardEvidence != null && source != quote.chainSource) {
        return const Err(ArkStaleQuoteFailure());
      }
      if (submission case ArkRegisterBoard()) {
        if (existing == null) return const Err(ArkValidationFailure());
        final funding = existing.operation.boardFunding;
        if (funding == null ||
            (funding.scuttleToken != null) != (quote.boardEvidence != null) ||
            funding.keypairIndex != submission.keypairIndex ||
            funding.expiryHeight != submission.expiryHeight) {
          return const Err(ArkValidationFailure());
        }
        final binding = jsonEncode({
          'psbt': submission.unfinalisedPsbt,
          'index': submission.keypairIndex,
          'expiry': submission.expiryHeight,
        });
        final registered = existing.evidence?['registration'];
        if (registered != null) {
          if (registered != binding) return const Err(ArkValidationFailure());
          return Ok(existing.operation);
        }
        if (existing.operation.status != ArkOperationStatus.prepared) {
          return Ok(existing.operation);
        }
        final currentTip = await _revalidate(store, session, quote);
        if (currentTip == null || funding.expiryHeight <= currentTip) {
          return const Err(ArkStaleQuoteFailure());
        }
        final inspected = await transactionVerifier.inspectBoardPsbt(
          unfinalisedPsbt: submission.unfinalisedPsbt,
          network: account.network,
        );
        if (inspected case Err(:final failure)) return Err(failure);
        final facts =
            (inspected as Ok<ArkBoardPsbtFacts, ArkWalletFailure>).value;
        final outputs = facts.outputs
            .where((o) => o.address == funding.address)
            .toList();
        if (facts.finalised ||
            !facts.nativeSegwitInputs ||
            outputs.length != 1 ||
            outputs.single.amount != quote.amount) {
          return const Err(ArkValidationFailure());
        }
        final admitted = _operation(
          quote,
          operationId,
          ArkOperationStatus.admitted,
          boardFunding: funding,
        );
        final evidence = {
          'registration': binding,
          'unsignedTxid': facts.unsignedTxid,
        };
        store.saveOperation(admitted, quoteId, evidence: evidence);
        try {
          final txid = await session.registerBoard(submission, funding);
          if (txid != facts.unsignedTxid) {
            throw const ArkBoundaryException(ArkValidationFailure());
          }
          final result = _operation(
            quote,
            operationId,
            ArkOperationStatus.pending,
            reference: txid,
            boardFunding: funding,
          );
          store.saveOperation(result, quoteId, evidence: evidence);
          return Ok(result);
        } catch (error) {
          if (error is Error) rethrow;
          store.saveOperation(
            _operation(
              quote,
              operationId,
              ArkOperationStatus.outcomeUnknown,
              boardFunding: funding,
            ),
            quoteId,
            evidence: evidence,
          );
          return Err(ArkOutcomeUnknownFailure(operationId));
        }
      }
      await _revalidate(store, session, quote);
      if (submission case ArkBoardFunding()) {
        if (quote.kind != ArkOperationKind.board) {
          return const Err(ArkValidationFailure());
        }
        store.saveOperation(
          _operation(quote, operationId, ArkOperationStatus.admitted),
          quoteId,
        );
        final ArkBoardFundingDetails funding;
        try {
          funding = await session.boardFunding();
        } catch (error) {
          if (error is Error) rethrow;
          store.saveOperation(
            _operation(quote, operationId, ArkOperationStatus.outcomeUnknown),
            quoteId,
          );
          return Err(ArkOutcomeUnknownFailure(operationId));
        }
        if (funding.expiryHeight <= quote.observedTip ||
            (funding.scuttleToken != null) != (quote.boardEvidence != null)) {
          store.saveOperation(
            _operation(quote, operationId, ArkOperationStatus.failed),
            quoteId,
          );
          return const Err(ArkStaleQuoteFailure());
        }
        final result = _operation(
          quote,
          operationId,
          ArkOperationStatus.prepared,
          boardFunding: funding,
        );
        store.saveOperation(result, quoteId);
        return Ok(result);
      }

      if (quote.kind == ArkOperationKind.board) {
        return const Err(ArkValidationFailure());
      }
      if (quote.kind == ArkOperationKind.claim) {
        return _claim(store, session, quote, operationId);
      }
      return Ok(await _executeQuote(store, session, quote, operationId));
    }, requiredSource: quote.chainSource);
  });

  Future<Result<ArkOperation, ArkWalletFailure>> _deliverSavedClaim(
    ArkStore store,
    ArkAccountId account,
    ArkRebroadcastClaim command,
  ) async {
    final record = store.operation(command.operationId);
    final raw = record?.evidence?['raw'];
    if (record == null ||
        raw is! String ||
        record.operation.kind != ArkOperationKind.claim ||
        record.operation.nativeReference != command.expectedTxid) {
      return const Err(ArkValidationFailure());
    }
    final verified = await _verifiedOperation(store, account, record.operation);
    if (verified.claimRecovery == null) {
      return const Err(ArkValidationFailure());
    }
    if (executionMode == ArkExecutionMode.backgroundExisting &&
        (store.quote(record.binding)?.reserveOutpoints.isNotEmpty ?? false)) {
      return const Err(ArkUnavailableFailure());
    }
    bool settled(ArkOperation value) =>
        value.status == ArkOperationStatus.succeeded ||
        value.status == ArkOperationStatus.conflicted;
    if (settled(verified)) {
      return Ok(verified);
    }
    if (!_mayRun(account)) {
      return const Err(ArkUnavailableFailure(ArkFailureReason.budgetExhausted));
    }
    final configured = store.get('config');
    if (configured == null) {
      return const Err(ArkValidationFailure());
    }
    final source = await preflight.select(
      configFromJson(configured),
      requiredSource: verified.chainSource,
    );
    if (source case Err(:final failure)) {
      return Err(failure);
    }
    if ((source as Ok<Uri, ArkWalletFailure>).value != verified.chainSource) {
      return const Err(ArkValidationFailure(ArkFailureReason.identityMismatch));
    }
    final current = store.operation(command.operationId);
    if (current == null ||
        current.binding != record.binding ||
        current.operation.nativeReference != command.expectedTxid) {
      return const Err(ArkValidationFailure());
    }
    if (settled(current.operation)) {
      return Ok(current.operation);
    }
    if (!_mayRun(account)) {
      return const Err(ArkUnavailableFailure(ArkFailureReason.budgetExhausted));
    }
    final unknown = operationFromJson({
      ...operationToJson(verified),
      'status': ArkOperationStatus.outcomeUnknown.name,
    });
    store.beginClaimDelivery(unknown, record.binding, now().toUtc());
    if (!_mayRun(account)) {
      return const Err(ArkUnavailableFailure(ArkFailureReason.budgetExhausted));
    }
    try {
      await claimDelivery.post(verified.chainSource, raw, command.expectedTxid);
      final pending = operationFromJson({
        ...operationToJson(verified),
        'status': ArkOperationStatus.pending.name,
      });
      store.saveOperation(pending, record.binding);
      return Ok(pending);
    } catch (error) {
      if (error is Error) rethrow;
      // Delivery/result persistence is uncertain. A later projection-write
      // failure may leave the stored operation pending; evidence and attempt
      // remain protected and retryable in either pending or unknown state.
      return Err(ArkOutcomeUnknownFailure(command.operationId));
    }
  }

  Future<int?> _revalidate(
    ArkStore store,
    ArkNativeSession session,
    ArkQuote quote,
  ) async {
    final previous = store.snapshot;
    if (previous == null ||
        previous.revision != quote.generation ||
        !quote.validUntil.isAfter(now())) {
      throw const ArkBoundaryException(ArkStaleQuoteFailure());
    }
    if (quote.boardEvidence != null) {
      // This check authorizes only preparing or registering an unsigned
      // board. It does not mark the inventory fresh or authorize signing.
      if (session is! ArkNativeLiveBoardSession ||
          _storedRecovery(store, previous) != ArkRecoveryStatus.complete) {
        throw const ArkBoundaryException(ArkStaleQuoteFailure());
      }
      await _reprice(storeSnapshot: previous, session: session, quote: quote);
      return quote.observedTip;
    }
    if (quote.kind == ArkOperationKind.claim &&
        quote.reserveOutpoints.isNotEmpty &&
        session is ArkNativeExitReserveSession) {
      // Repricing independently proves this exact sweep against the active
      // chain; it confers no freshness on the rest of the wallet.
      await _reprice(storeSnapshot: previous, session: session, quote: quote);
      return quote.observedTip;
    }
    if (quote.kind == ArkOperationKind.emergencyExit &&
        session is ArkNativeExitReserveSession) {
      final reserve = store.initialExitReserve(quote);
      if (reserve == null ||
          previous.reserveAddress != reserve.address ||
          previous.exits != ArkExitStatus.none ||
          quote.confirmedReserveExposure != reserve.funding.amount ||
          !await session.verifyInitialExitReserve(
            reserve.funding,
            reserve.address,
          )) {
        throw const ArkBoundaryException(ArkStaleQuoteFailure());
      }
      await _reprice(storeSnapshot: previous, session: session, quote: quote);
      return quote.observedTip;
    }
    if (_SyncFailures.load(store, quote.account).causes.isNotEmpty) {
      throw const ArkBoundaryException(ArkStaleQuoteFailure());
    }
    if (quote.kind == ArkOperationKind.board) {
      await session.synchronizeStage('server');
    }
    var nativeStale = true;
    final fresh = await _observe(
      store,
      session,
      quote.account,
      quote.chainSource,
      commit: false,
      revision: quote.generation,
      onNativeStaleness: (stale) => nativeStale = stale,
    );
    final protective =
        quote.kind == ArkOperationKind.emergencyExit ||
        quote.kind == ArkOperationKind.exitProgress ||
        quote.kind == ArkOperationKind.claim;
    if ((protective ? nativeStale : fresh.stale) ||
        (!protective &&
            (fresh.recovery != ArkRecoveryStatus.complete ||
                !fresh.vtxoInventoryComplete)) ||
        fresh.tipHeight != quote.observedTip ||
        (previous.serverInfo?.publicKey != fresh.serverInfo?.publicKey)) {
      throw const ArkBoundaryException(ArkStaleQuoteFailure());
    }
    await _reprice(storeSnapshot: fresh, session: session, quote: quote);
    return fresh.tipHeight;
  }

  Future<void> _reprice({
    required ArkSnapshot storeSnapshot,
    required ArkNativeSession session,
    required ArkQuote quote,
  }) async {
    final renewed = await session.estimate(
      snapshot: storeSnapshot,
      request: _request(quote),
      id: quote.id,
      chainSource: quote.chainSource,
      configGeneration: quote.configGeneration,
      now: now(),
    );
    final oldJson = quoteToJson(quote)..remove('until');
    final nextJson = quoteToJson(renewed)..remove('until');
    if (!quote.validUntil.isAfter(now()) ||
        jsonEncode(oldJson) != jsonEncode(nextJson)) {
      throw const ArkBoundaryException(ArkStaleQuoteFailure());
    }
  }

  ArkQuoteRequest _request(ArkQuote quote) {
    final destination = quote.destination;
    final destinationKind = quote.destinationKind;
    final feeRate = quote.feeRate;
    final maxClaimFee = quote.maxClaimFee;
    return switch (quote.kind) {
      ArkOperationKind.payment
          when destination != null && destinationKind != null =>
        ArkQuoteRequest.payment(
          destination: ArkPaymentDestination(
            kind: destinationKind,
            value: destination,
          ),
          amount: quote.net,
        ),
      ArkOperationKind.renewal => ArkQuoteRequest.renewal(
        ids: quote.selectedIds,
      ),
      ArkOperationKind.board => ArkQuoteRequest.board(amount: quote.amount),
      // The rate and ceiling the quote recorded, never fresh automatic ones:
      // a replay must price exactly what was reviewed.
      ArkOperationKind.emergencyExit
          when destination != null && feeRate != null && maxClaimFee != null =>
        ArkQuoteRequest.emergencyExit(
          ids: quote.selectedIds,
          destination: destination,
          feeRate: feeRate,
          maxClaimFee: maxClaimFee,
        ),
      ArkOperationKind.exitProgress when feeRate != null =>
        ArkQuoteRequest.exitProgress(feeRate: feeRate),
      ArkOperationKind.claim when destination != null && maxClaimFee != null =>
        ArkQuoteRequest.claim(
          ids: quote.selectedIds,
          destination: destination,
          maxFee: maxClaimFee,
          reserveSweepFeeRate: quote.reserveOutpoints.isEmpty
              ? null
              : quote.feeRate,
        ),
      _ => throw const ArkBoundaryException(ArkValidationFailure()),
    };
  }

  Future<ArkOperation> _executeQuote(
    ArkStore store,
    ArkNativeSession session,
    ArkQuote quote,
    String id,
  ) async {
    final admitted = _operation(
      quote,
      id,
      ArkOperationStatus.admitted,
      actualIds: quote.selectedIds,
    );
    if (quote.kind == ArkOperationKind.emergencyExit) {
      if (!store.admitExit(
        quote,
        admitted,
        requireInitialReserve: session is ArkNativeExitReserveSession,
      )) {
        throw const ArkBoundaryException(ArkValidationFailure());
      }
    } else {
      store.saveOperation(admitted, quote.id);
    }
    try {
      final result = await session.execute(quote, id);
      store.saveOperation(result, quote.id);
      return result;
    } catch (error) {
      if (error is Error) rethrow;
      final unknown = _operation(
        quote,
        id,
        ArkOperationStatus.outcomeUnknown,
        actualIds: quote.selectedIds,
      );
      store.saveOperation(unknown, quote.id);
      return unknown;
    }
  }

  Future<Result<ArkOperation, ArkWalletFailure>> _claim(
    ArkStore store,
    ArkNativeSession session,
    ArkQuote quote,
    String id,
  ) async {
    final destination = quote.destination;
    final maximum = quote.maxClaimFee;
    if (destination == null || maximum == null) {
      return const Err(ArkValidationFailure());
    }
    if (!_mayRun(quote.account)) {
      return const Err(ArkUnavailableFailure(ArkFailureReason.budgetExhausted));
    }
    if (session is ArkNativeExitReserveSession &&
        (quote.reserveOutpoints.isEmpty ||
            store.claimAuthority(quote.selectedIds, destination, maximum) ==
                null)) {
      return const Err(ArkUnavailableFailure());
    }
    final admitted = _operation(
      quote,
      id,
      ArkOperationStatus.admitted,
      actualIds: quote.selectedIds,
    );
    final authority = store.admitClaim(quote, admitted);
    if (authority == null) return const Err(ArkValidationFailure());
    try {
      await exitObserver?.claimAdmitted(quote.account, admitted);
    } on Exception {
      // A notification failure must never change claim authority.
    }
    try {
      final claim = await session.prepareClaim(quote);
      final actual = claim.actualIds.toSet();
      final skipped = claim.skippedIds.toSet();
      if (actual.isEmpty ||
          actual.length != claim.actualIds.length ||
          skipped.length != claim.skippedIds.length ||
          actual.intersection(skipped).isNotEmpty ||
          actual
              .union(skipped)
              .difference(quote.selectedIds.toSet())
              .isNotEmpty ||
          quote.selectedIds
              .toSet()
              .difference(actual.union(skipped))
              .isNotEmpty) {
        throw const ArkBoundaryException(ArkValidationFailure());
      }
      final expected = ArkSavedClaim.expectedInputs(quote, actual, skipped);
      final inspected = await transactionVerifier.inspectTransaction(
        transactionHex: claim.rawTransaction,
        signedPsbt: claim.signedPsbt,
        network: quote.account.network,
      );
      if (inspected case Err(:final failure)) {
        throw ArkBoundaryException(failure);
      }
      final facts =
          (inspected as Ok<ArkTransactionFacts, ArkWalletFailure>).value;
      final inputs = facts.inputs;
      final outputs = facts.outputs;
      final total = inputs.fold<BigInt>(
        BigInt.zero,
        (sum, input) => sum + input.amount.value,
      );
      if (facts.txid != facts.psbtTxid ||
          inputs.length != expected.length ||
          inputs.map((v) => v.outpoint).toSet().length != inputs.length ||
          !inputs.every(
            (v) =>
                expected.contains(v.outpoint) &&
                v.finalWitness &&
                claim.inputAmounts[v.outpoint] == v.amount.toString(),
          ) ||
          outputs.length != 1 ||
          outputs.single.address != destination ||
          outputs.single.amount.value + facts.fee.value != total ||
          !ArkSavedClaim.matchesMixedReview(
            quote,
            total,
            facts.fee,
            outputs.single.amount,
          ) ||
          facts.fee.value > maximum.value ||
          facts.fee.toString() != claim.fee ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(facts.txid)) {
        throw const ArkBoundaryException(ArkValidationFailure());
      }
      final summary = ArkClaimRecovery(
        txid: facts.txid,
        destination: destination,
        net: outputs.single.amount,
        fee: facts.fee,
      );
      // Debit the cumulative authority and persist exact signed bytes BEFORE broadcast.
      final pending = _operation(
        quote,
        id,
        ArkOperationStatus.admitted,
        reference: facts.txid,
        claimRecovery: summary,
        actualIds: claim.actualIds,
        skippedIds: claim.skippedIds,
      );
      store.commitClaim(
        authority,
        pending,
        quote.id,
        actual,
        facts.fee,
        ArkSavedClaim.evidence(
          quote: quote,
          operationId: id,
          claim: claim,
          summary: summary,
        ),
      );
      final String txid;
      if (session is ArkNativeExitReserveSession) {
        store.beginClaimDelivery(pending, quote.id, now().toUtc());
        if (!_mayRun(quote.account)) {
          throw const ArkBoundaryException(
            ArkUnavailableFailure(ArkFailureReason.budgetExhausted),
          );
        }
        await claimDelivery.post(
          quote.chainSource,
          claim.rawTransaction,
          facts.txid,
        );
        txid = facts.txid;
      } else {
        txid = await session.broadcast(claim.rawTransaction);
      }
      if (txid != facts.txid) {
        throw const ArkBoundaryException(ArkValidationFailure());
      }
      final result = _operation(
        quote,
        id,
        ArkOperationStatus.pending,
        reference: txid,
        claimRecovery: summary,
        actualIds: claim.actualIds,
        skippedIds: claim.skippedIds,
      );
      store.saveOperation(result, quote.id);
      return Ok(result);
    } catch (error) {
      if (error is Error) rethrow;
      final record = store.operation(id);
      final previous = record?.operation;
      final committed = record?.evidence?['raw'] != null;
      store.saveOperation(
        _operation(
          quote,
          id,
          committed
              ? ArkOperationStatus.outcomeUnknown
              : ArkOperationStatus.failed,
          reference: previous?.nativeReference,
          claimRecovery: previous?.claimRecovery,
          actualIds: previous?.actualIds ?? const [],
          skippedIds: previous?.skippedIds ?? const [],
        ),
        quote.id,
      );
      if (committed) return Err(ArkOutcomeUnknownFailure(id));
      return Err(
        error is ArkBoundaryException
            ? error.failure
            : const ArkNativeFailure(),
      );
    }
  }

  @override
  Future<Result<ArkReceiveDestination, ArkWalletFailure>> receive(
    ArkAccountId account,
    ArkReceiveRequest request,
  ) => _exclusive(account, (store, path) async {
    if (executionMode != ArkExecutionMode.foreground) {
      return const Err(ArkUnavailableFailure());
    }
    return _session(
      store,
      path,
      account,
      (session, source, stages) async => Ok(await session.receive(request)),
    );
  });

  @override
  Future<Result<DateTime, ArkWalletFailure>> nextRound(ArkAccountId account) =>
      _exclusive(account, (store, path) async {
        if (executionMode != ArkExecutionMode.foreground) {
          return const Err(ArkUnavailableFailure());
        }
        return _session(
          store,
          path,
          account,
          (session, source, stages) async => Ok(await session.nextRoundStart()),
        );
      });
  static ArkOperation _operation(
    ArkQuote quote,
    String id,
    ArkOperationStatus status, {
    String? reference,
    ArkClaimRecovery? claimRecovery,
    ArkBoardFundingDetails? boardFunding,
    List<String> actualIds = const [],
    List<String> skippedIds = const [],
  }) => ArkOperation(
    id: id,
    kind: quote.kind,
    status: status,
    chainSource: quote.chainSource,
    configGeneration: quote.configGeneration,
    nativeReference: reference,
    claimRecovery: claimRecovery,
    boardFunding: boardFunding,
    actualIds: actualIds,
    skippedIds: skippedIds,
  );
  static String _id() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  @override
  Future<void> close() async {
    _closing = true;
    await Future.wait(_inflight.toList());
    for (final controller in _changes.values) {
      await controller.close();
    }
    _changes.clear();
  }
}

final class _Stages implements ArkStageRunner {
  final bool Function() mayAdmit;
  _Stages(this.mayAdmit);
  @override
  Future<T> run<T>(String name, Future<T> Function() action) async {
    if (!mayAdmit()) throw const ArkStageDeferred();
    // No timeout: close and lock release await this exact future.
    return await action();
  }
}

ArkSnapshot copySnapshot(
  ArkSnapshot value, {
  bool? stale,
  List<ArkOperation>? operations,
  ArkRenewalStatus? renewal,
  ArkSectionCompleteness? vtxoCompleteness,
  String? reserveAddress,
  List<ArkVtxo>? vtxos,
  Sats? pending,
  Sats? pendingBoardBalance,
  ArkServerInfo? serverInfo,
}) => ArkSnapshot(
  account: value.account,
  revision: value.revision,
  observedAt: value.observedAt,
  tipHeight: value.tipHeight,
  stale: stale ?? value.stale,
  spendable: value.spendable,
  pending: pending ?? value.pending,
  pendingBoardBalance: pendingBoardBalance ?? value.pendingBoardBalance,
  confirmedReserve: value.confirmedReserve,
  vtxos: vtxos ?? value.vtxos,
  movements: value.movements,
  operations: operations ?? value.operations,
  serverInfo: serverInfo ?? value.serverInfo,
  renewal: renewal ?? value.renewal,
  exits: value.exits,
  recovery: value.recovery,
  obligations: value.obligations,
  pendingBoardCount: value.pendingBoardCount,
  pendingLightningCount: value.pendingLightningCount,
  pendingRoundCount: value.pendingRoundCount,
  reserveAddress: reserveAddress ?? value.reserveAddress,
  usingFallback: value.usingFallback,
  exitDetails: value.exitDetails,
  pendingBoards: value.pendingBoards,
  vtxoCompleteness: vtxoCompleteness ?? value.vtxoCompleteness,
);

/// Matching stage completion is provisional until a complete sync commits.
final class _SyncFailures {
  final ArkAccountId account;
  final List<Map<String, Object?>> causes;
  List<Map<String, Object?>> candidate;
  _SyncFailures(this.account, this.causes) : candidate = [...causes];
  static const stages = {
    'ark',
    'lightning',
    'rounds',
    'boards',
    'offboards',
    'server',
    'onchain',
    'exits-observe',
    'observe',
  };
  static _SyncFailures load(ArkStore store, ArkAccountId account) {
    final data = store.get('sync-stage-failures');
    if (data == null) return _SyncFailures(account, []);
    final rows = data['causes'];
    if (data['account'] != account.canonical ||
        rows is! List ||
        rows.length > 16) {
      throw const FormatException('Invalid synchronization evidence binding');
    }
    final config = configFromJson(store.get('config') ?? {});
    if (config.id != account) {
      throw const FormatException('Invalid synchronization account');
    }
    final maxRevision = (store.snapshot?.revision ?? 0) + 1;
    final sources = {
      config.primaryEsploraUrl.toString(),
      config.fallbackEsploraUrl?.toString(),
    };
    final causes = <Map<String, Object?>>[];
    final seen = <(Object?, Object?)>{};
    for (final row in rows) {
      if (row is! Map<String, dynamic> ||
          !stages.contains(row['stage']) ||
          !{'failed', 'deferred'}.contains(row['kind']) ||
          row['source'] is! String ||
          !sources.contains(row['source']) ||
          row['generation'] is! int ||
          row['generation'] != 1 ||
          row['revision'] is! int ||
          (row['revision'] as int) < 0 ||
          (row['revision'] as int) > maxRevision ||
          !seen.add((row['stage'], row['source']))) {
        throw const FormatException('Invalid synchronization cause');
      }
      causes.add(Map<String, Object?>.from(row));
    }
    return _SyncFailures(account, causes);
  }

  Map<String, Object?> encode(List<Map<String, Object?>> values) => {
    'account': account.canonical,
    'causes': values,
  };
  void record(
    ArkStore store,
    String stage,
    bool failed,
    Uri source,
    int revision,
  ) {
    final prior = causes
        .where((c) => c['stage'] == stage && c['source'] == source.toString())
        .firstOrNull;
    causes.removeWhere(
      (c) => c['stage'] == stage && c['source'] == source.toString(),
    );
    causes.add({
      'stage': stage,
      'kind': failed || prior?['kind'] == 'failed' ? 'failed' : 'deferred',
      'source': source.toString(),
      'generation': 1,
      'revision': revision,
    });
    candidate = [...causes];
    store.put('sync-stage-failures', encode(causes));
  }

  void resolve(Set<String> completed, Uri source) {
    candidate = causes
        .where(
          (cause) =>
              cause['source'] != source.toString() ||
              !completed.contains(cause['stage']),
        )
        .toList();
  }
}
