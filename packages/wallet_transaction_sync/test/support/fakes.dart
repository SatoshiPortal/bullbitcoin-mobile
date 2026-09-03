import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

const testKey = WalletNetworkKey('w', 'bitcoin', 'testnet');

const testRegistration = WalletSourceRegistration(
  key: testKey,
  sourceKind: 'fake',
  configurationFingerprint: 'one',
);

WalletTransactionSyncFacade buildFacade(
  RecordingSource source,
  RecordingMetadata metadata,
) => WalletTransactionSyncFacade(
  source: source,
  metadata: metadata,
  coordinator: InMemoryWalletSourceOperationCoordinator(),
);

T okValue<T>(Result<T, WalletTransactionSyncFailure> result) =>
    (result as Ok<T, WalletTransactionSyncFailure>).value;

WalletTransactionSyncFailure errFailure<T>(
  Result<T, WalletTransactionSyncFailure> result,
) => (result as Err<T, WalletTransactionSyncFailure>).failure;

WalletTransactionSyncFailure? errFailureOrNull<T>(
  Result<T, WalletTransactionSyncFailure> result,
) => result is Err<T, WalletTransactionSyncFailure> ? result.failure : null;

class RecordingSource implements WalletTransactionSourcePort {
  WalletSourceObservation Function(WalletSourceRegistration registration)?
  observationBuilder;
  List<WalletTransaction> baselineTransactions = const [];
  WalletTransactionSyncFailure? failure;
  int refreshCalls = 0;
  int syncCalls = 0;
  int deleteCalls = 0;
  int deleteFailuresRemaining = 0;
  Completer<void>? pauseRefresh;
  Completer<void>? refreshEntered;
  Completer<void>? pauseSync;
  Completer<void>? syncEntered;

  static WalletSourceObservation defaultObservation(
    WalletSourceRegistration registration,
  ) => WalletSourceObservation(
    key: registration.key,
    registration: registration,
    transactions: [
      WalletTransaction(
        txid: 'a',
        amountSats: 10,
        position: const UnknownPosition(),
      ),
    ],
  );

  WalletSourceObservation _observation(WalletSourceRegistration registration) {
    final observation = (observationBuilder ?? defaultObservation)(
      registration,
    );
    return WalletSourceObservation(
      key: observation.key,
      registration: observation.registration,
      transactions: observation.transactions,
      capabilities: observation.capabilities,
      sourceTip: observation.sourceTip,
      complete: observation.complete,
      evidenceLevel: observation.evidenceLevel,
    );
  }

  @override
  Future<Result<WalletSourceObservation, WalletTransactionSyncFailure>>
  refreshLocal(
    WalletSourceRegistration registration,
    WalletSourceSession session,
  ) async {
    session.ensureOpen();
    refreshCalls++;
    refreshEntered?.complete();
    refreshEntered = null;
    final pause = pauseRefresh;
    if (pause != null) {
      pauseRefresh = null;
      await pause.future;
    }
    final currentFailure = failure;
    return currentFailure == null
        ? Ok(_observation(registration))
        : Err(currentFailure);
  }

  @override
  Future<Result<WalletSourceSyncObservation, WalletTransactionSyncFailure>>
  synchronize(
    WalletSourceRegistration registration,
    WalletSourceSession session, {
    required bool discover,
  }) async {
    session.ensureOpen();
    syncCalls++;
    syncEntered?.complete();
    syncEntered = null;
    final pause = pauseSync;
    if (pause != null) {
      pauseSync = null;
      await pause.future;
    }
    final currentFailure = failure;
    return currentFailure == null
        ? Ok(
            WalletSourceSyncObservation(
              observation: _observation(registration),
              baselineTxids: baselineTransactions
                  .map((transaction) => transaction.txid)
                  .toSet(),
            ),
          )
        : Err(currentFailure);
  }

  @override
  Future<Result<void, WalletTransactionSyncFailure>> delete(
    WalletNetworkKey key,
    WalletSourceSession session, {
    WalletSourceRegistration? registration,
  }) async {
    session.ensureOpen();
    deleteCalls++;
    if (deleteFailuresRemaining > 0) {
      deleteFailuresRemaining--;
      return Err(const DeletionFailure(safeMessage: 'source delete failed'));
    }
    return const Ok(null);
  }
}

class RecordingMetadata implements WalletSyncMetadataPort {
  final Map<WalletNetworkKey, WalletSyncMetadata> values = {};
  final Map<WalletNetworkKey, WalletSyncReceipt> receipts = {};
  bool failSuccess = false;
  bool failRead = false;
  int clearFailuresRemaining = 0;

  @override
  Future<WalletSyncMetadata?> read(WalletNetworkKey key) async {
    if (failRead) throw StateError('metadata store unavailable');
    return values[key];
  }

  @override
  Future<void> writeRegistration(WalletSourceRegistration registration) async {
    values.putIfAbsent(
      registration.key,
      () => WalletSyncMetadata(registration: registration),
    );
  }

  @override
  Future<void> writeAttempt(WalletNetworkKey key, DateTime at) async {}

  @override
  Future<void> writeSuccess(
    WalletNetworkKey key,
    DateTime at,
    String fingerprint,
  ) async {
    if (failSuccess) throw StateError('metadata store unavailable');
    final old = values[key];
    if (old != null) {
      values[key] = WalletSyncMetadata(
        registration: old.registration,
        lastSuccessfulSyncAt: at,
        contentFingerprint: fingerprint,
      );
    }
  }

  @override
  Future<WalletSyncReceipt?> readReceipt(WalletNetworkKey key) async =>
      receipts[key];

  @override
  Future<void> writeReceipt(WalletSyncReceipt receipt) async {
    if (failSuccess) throw StateError('metadata store unavailable');
    receipts[receipt.key] = receipt;
  }

  @override
  Future<void> writeDeletionMarker(
    WalletNetworkKey key,
    WalletDeletionPhase phase,
  ) async {
    final old = values[key];
    values[key] = WalletSyncMetadata(
      registration: old?.registration ?? testRegistration,
      lastAttemptedSyncAt: old?.lastAttemptedSyncAt,
      lastSuccessfulSyncAt: old?.lastSuccessfulSyncAt,
      contentFingerprint: old?.contentFingerprint,
      deletionPending: true,
      deletionPhase: phase,
    );
  }

  @override
  Future<void> clear(WalletNetworkKey key) async {
    if (clearFailuresRemaining > 0) {
      clearFailuresRemaining--;
      throw StateError('metadata clear failed');
    }
    values.remove(key);
    receipts.remove(key);
  }
}
