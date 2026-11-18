import 'dart:async';

import 'package:ark/ark.dart';
import 'package:ark/src/domain/ark_execution_policy.dart'
    show
        ArkChildProviderPort,
        ArkExecutionPolicyPort,
        ArkExecutionMode,
        ArkStageBudget;
import 'package:ark/src/data/ark_chain_preflight.dart';
import 'package:ark/src/data/ark_native_session.dart';
import 'package:primitives/primitives.dart';

final class FakeChild implements ArkChildProviderPort {
  int calls = 0;
  bool failOnce = false;
  @override
  Future<Result<T, ArkWalletFailure>> withChild<T>(
    ArkAccountId account,
    Future<Result<T, ArkWalletFailure>> Function(String, Fingerprint) action,
  ) {
    calls++;
    if (failOnce) {
      failOnce = false;
      return Future.value(const Err(ArkUnavailableFailure()));
    }
    return action('test-provider-placeholder', Fingerprint('53bdf6b1'));
  }
}

final class FakePolicy implements ArkExecutionPolicyPort {
  bool allowed = true;
  @override
  bool mayRun(ArkAccountId account, ArkExecutionMode mode) => allowed;
}

final class FakeBudget implements ArkStageBudget {
  bool allowed = true;
  @override
  bool get mayAdmitNextStage => allowed;
}

final class FakePreflight implements ArkChainPreflight {
  int calls = 0;
  int failuresRemaining = 0;
  Future<void> Function()? beforeSelect;
  bool primaryUnreachable = false;
  final List<Uri?> requiredSources = [];
  @override
  Future<Result<Uri, ArkWalletFailure>> select(
    ArkAccountConfig config, {
    Uri? requiredSource,
    int? minimumTip,
  }) async {
    calls++;
    requiredSources.add(requiredSource);
    final wait = beforeSelect;
    if (wait != null) {
      await wait();
    }
    if (failuresRemaining > 0) {
      failuresRemaining--;
      return const Err(ArkUnavailableFailure());
    }
    if (primaryUnreachable) {
      if (requiredSource == config.primaryEsploraUrl) {
        return const Err(
          ArkUnavailableFailure(ArkFailureReason.chainUnreachable),
        );
      }
      return Ok(
        requiredSource ?? config.fallbackEsploraUrl ?? config.primaryEsploraUrl,
      );
    }
    return Ok(requiredSource ?? config.primaryEsploraUrl);
  }
}

final class FakeOpener implements ArkNativeOpener {
  bool exists = false;
  ArkRecoveryStatus recovery = ArkRecoveryStatus.complete;
  bool failBeforeRecoveryCallback = false;
  bool failInitialScan = false;
  int opens = 0;
  int creates = 0;
  int closes = 0;
  int executes = 0;
  int broadcasts = 0;
  int preparations = 0;
  int claimFee = 10;
  List<String>? claimableIds;
  List<ArkExit> exitDetails = [];
  int registrations = 0;
  int fundings = 0;
  int boardExpiry = 2000;
  int tip = 100;
  bool failExecute = false;
  bool requireBoardServerInfo = false;
  final boardServerEvents = <String>[];
  Future<ArkClaimTransaction> Function(ArkQuote)? claimPreparer;
  bool reconcileSuccess = false;
  bool missingVtxos = false;
  List<ArkVtxo>? inventoryOverride;
  bool observationStale = false;
  Sats pendingAmount = Sats.zero;
  Sats? pendingBoardBalance;
  List<ArkPendingBoard> pendingBoards = [];
  ArkSectionCompleteness inventoryCompleteness =
      ArkSectionCompleteness.complete;
  ArkRenewalStatus renewalStatus = ArkRenewalStatus.due;
  bool spentWithoutEvidence = false;
  List<ArkMovement> movementEvidence = [];
  String? failingStage;
  Completer<void>? stageEntered;
  Completer<void>? releaseStage;
  void Function(String)? afterStage;
  static final firstId = '${'a' * 64}:0';
  static final secondId = '${'b' * 64}:1';
  List<String> claimActual = [firstId];
  List<String> claimSkipped = [];
  @override
  bool datadirExists(String path) => exists;
  @override
  Future<ArkNativeSession> open({
    required ArkAccountConfig config,
    required String datadir,
    required String mnemonic,
    required Fingerprint childFingerprint,
    required Uri chainSource,
    required bool create,
    required String? expectedFingerprint,
    required bool nativePreviouslyAdmitted,
    required void Function() onNativeAdmission,
    required ArkStageRunner stages,
    required void Function() onOnchainOpened,
    required void Function(ArkRecoveryStatus recovery, String fingerprint)
    onOpened,
  }) async {
    return stages.run('open', () async {
      if (nativePreviouslyAdmitted && !exists) {
        throw const ArkBoundaryException(ArkRecoveryRequiredFailure());
      }
      onNativeAdmission();
      opens++;
      if (create && !exists) creates++;
      exists = true;
      onOnchainOpened();
      if (failBeforeRecoveryCallback) {
        failBeforeRecoveryCallback = false;
        throw Exception('open interrupted');
      }
      onOpened(opens == 1 ? recovery : ArkRecoveryStatus.notRun, 'cafefeed');
      return FakeSession(this, config, stages);
    });
  }
}

final class FakeSession implements ArkNativeSession {
  final FakeOpener owner;
  final ArkAccountConfig config;
  final ArkStageRunner stages;
  bool serverReady = false;
  FakeSession(this.owner, this.config, this.stages);
  @override
  void close() {
    owner.closes++;
  }

  @override
  Future<void> synchronizeStage(String name) => stages.run(name, () async {
    if (name == 'ark' && owner.stageEntered != null) {
      owner.stageEntered?.complete();
      await owner.releaseStage?.future;
    }
    if (owner.requireBoardServerInfo && name == 'server') {
      owner.boardServerEvents.add('server');
    }
    if (owner.failingStage == name) throw Exception('stage refused');
    if (name == 'server') serverReady = true;
    if (name == 'initial-scan' && owner.failInitialScan) {
      owner.failInitialScan = false;
      throw Exception('scan failure');
    }
    owner.afterStage?.call(name);
  });
  @override
  Future<ArkSnapshot> observe({
    required ArkAccountId account,
    required int revision,
    required DateTime now,
    required Uri chainSource,
    required List<ArkOperation> operations,
    required ArkRecoveryStatus previousRecovery,
  }) => stages.run('observe', () async {
    if (owner.failingStage == 'observe') {
      throw Exception('observation unavailable');
    }
    if (owner.requireBoardServerInfo) owner.boardServerEvents.add('observe');
    return ArkSnapshot(
      serverInfo: owner.requireBoardServerInfo && serverReady
          ? ArkServerInfo(
              publicKey: 'server-key',
              minimumBoard: Sats.fromInt(1000),
            )
          : null,
      account: account,
      revision: revision,
      observedAt: now,
      tipHeight: owner.tip,
      stale: owner.observationStale,
      spendable: Sats.fromInt(20000),
      pending: owner.pendingAmount,
      pendingBoardBalance: owner.pendingBoardBalance,
      confirmedReserve: Sats.fromInt(5000),
      vtxos:
          owner.inventoryOverride ??
          (owner.missingVtxos
              ? []
              : [
                  for (final id in [FakeOpener.firstId, FakeOpener.secondId])
                    ArkVtxo(
                      id: id,
                      amount: Sats.fromInt(10000),
                      expiryHeight: 1100,
                      state: owner.spentWithoutEvidence
                          ? ArkVtxoState.spent
                          : ArkVtxoState.spendable,
                    ),
                ]),
      recovery: previousRecovery,
      renewal: owner.renewalStatus,
      exits: owner.exitDetails.isEmpty
          ? ArkExitStatus.none
          : ArkExitStatus.claimable,
      exitDetails: owner.exitDetails,
      obligations: ArkObligationStatus.present,
      pendingBoardCount: owner.pendingBoards.length,
      pendingBoards: owner.pendingBoards,
      pendingLightningCount: 0,
      pendingRoundCount: 0,
      operations: operations,
      movements: owner.movementEvidence,
      vtxoCompleteness: owner.inventoryCompleteness,
    );
  });
  @override
  Future<ArkQuote> estimate({
    required ArkSnapshot snapshot,
    required ArkQuoteRequest request,
    required String id,
    required Uri chainSource,
    required int configGeneration,
    required DateTime now,
  }) => stages.run('estimate', () async {
    if (request case ArkClaimQuoteRequest(:final ids)) {
      final claimable = owner.claimableIds;
      if (claimable != null && !ids.every(claimable.contains)) {
        throw const ArkBoundaryException(ArkValidationFailure());
      }
    }
    if (owner.requireBoardServerInfo && request is ArkBoardQuoteRequest) {
      owner.boardServerEvents.add('estimate-board');
      if (snapshot.serverInfo == null) {
        throw const ArkBoundaryException(ArkValidationFailure());
      }
    }
    final kind = switch (request) {
      ArkPaymentQuoteRequest() => ArkOperationKind.payment,
      ArkRenewalQuoteRequest() => ArkOperationKind.renewal,
      ArkEmergencyExitQuoteRequest() => ArkOperationKind.emergencyExit,
      ArkExitProgressQuoteRequest() => ArkOperationKind.exitProgress,
      ArkClaimQuoteRequest() => ArkOperationKind.claim,
      ArkBoardQuoteRequest() => ArkOperationKind.board,
    };
    final amount = switch (request) {
      ArkPaymentQuoteRequest(:final amount) => amount,
      ArkBoardQuoteRequest(:final amount) => amount,
      _ => Sats.fromInt(10000),
    };
    final destination = switch (request) {
      ArkPaymentQuoteRequest(:final destination) => destination.value,
      ArkEmergencyExitQuoteRequest(:final destination) => destination,
      ArkClaimQuoteRequest(:final destination) => destination,
      _ => null,
    };
    final selected = switch (request) {
      ArkRenewalQuoteRequest(:final ids) => ids,
      ArkEmergencyExitQuoteRequest(:final ids) => ids,
      ArkClaimQuoteRequest(:final ids) => ids,
      ArkBoardQuoteRequest() => const <String>[],
      _ => [FakeOpener.firstId],
    };
    final max = switch (request) {
      ArkEmergencyExitQuoteRequest(:final maxClaimFee) => maxClaimFee,
      ArkClaimQuoteRequest(:final maxFee) => maxFee,
      _ => null,
    };
    final estimatedFee = kind == ArkOperationKind.claim ? owner.claimFee : 10;
    return ArkQuote(
      id: id,
      account: snapshot.account,
      generation: snapshot.revision,
      chainSource: chainSource,
      configGeneration: configGeneration,
      kind: kind,
      amount: Sats(
        amount.value + BigInt.from(kind == ArkOperationKind.payment ? 10 : 0),
      ),
      fee: Sats.fromInt(estimatedFee),
      net: kind == ArkOperationKind.payment
          ? amount
          : Sats(amount.value - BigInt.from(estimatedFee)),
      selectedIds: selected,
      destination: destination,
      destinationKind: switch (request) {
        ArkPaymentQuoteRequest(:final destination) => destination.kind,
        _ => null,
      },
      observedTip: owner.tip,
      validUntil: now.add(const Duration(minutes: 2)),
      maxClaimFee: max,
      feeRate: switch (request) {
        ArkEmergencyExitQuoteRequest(:final feeRate) => feeRate,
        ArkExitProgressQuoteRequest(:final feeRate) => feeRate,
        _ => null,
      },
    );
  });
  @override
  Future<ArkOperation> execute(ArkQuote quote, String operationId) =>
      stages.run('execute', () async {
        owner.executes++;
        if (owner.failExecute) throw Exception('opaque native failure');
        return ArkOperation(
          id: operationId,
          kind: quote.kind,
          status: ArkOperationStatus.pending,
          chainSource: quote.chainSource,
          configGeneration: quote.configGeneration,
          nativeReference: '123',
          actualIds: quote.selectedIds,
        );
      });
  @override
  Future<List<String>> renewalCandidates() => stages.run(
    'renewal-candidates',
    () async => [FakeOpener.firstId, FakeOpener.secondId],
  );
  @override
  Future<String> reserveAddress() =>
      stages.run('reserve-address', () async => 'reserve-address');
  @override
  Future<ArkBoardFundingDetails> boardFunding() =>
      stages.run('funding', () async {
        owner.fundings++;
        return ArkBoardFundingDetails(
          address: 'funding-address',
          keypairIndex: 4,
          expiryHeight: owner.boardExpiry,
        );
      });
  @override
  Future<String> registerBoard(ArkRegisterBoard submission) =>
      stages.run('register', () async {
        owner.registrations++;
        return 'c' * 64;
      });
  @override
  Future<ArkClaimTransaction> prepareClaim(ArkQuote quote) =>
      stages.run('prepare-claim', () async {
        owner.preparations++;
        final prepare = owner.claimPreparer;
        if (prepare != null) {
          return prepare(quote);
        }
        return ArkClaimTransaction(
          rawTransaction: 'raw-public',
          signedPsbt: 'signed-public',
          actualIds: owner.claimActual,
          skippedIds: owner.claimSkipped,
          inputAmounts: {for (final id in owner.claimActual) id: '10000'},
          fee: owner.claimFee.toString(),
        );
      });
  @override
  Future<String> broadcast(String rawTransaction) =>
      stages.run('broadcast', () async {
        owner.broadcasts++;
        return 'd' * 64;
      });
  @override
  Future<ArkReceiveDestination> receive(ArkReceiveRequest request) =>
      stages.run(
        'receive',
        () async => ArkReceiveDestination(
          kind: ArkDestinationKind.ark,
          value: 'address',
        ),
      );
  @override
  Future<ArkOperation?> reconcile(ArkOperation operation) =>
      stages.run('reconcile', () async {
        if (!owner.reconcileSuccess) return null;
        return ArkOperation(
          id: operation.id,
          kind: operation.kind,
          status: ArkOperationStatus.succeeded,
          chainSource: operation.chainSource,
          configGeneration: operation.configGeneration,
          nativeReference: operation.nativeReference,
          actualIds: operation.actualIds,
          skippedIds: operation.skippedIds,
          boardFunding: operation.boardFunding,
        );
      });
}

final class FakeVerifier implements ArkTransactionVerifierPort {
  bool finalised = false;
  bool wrongInputs = false;
  int fee = 10;
  @override
  Future<Result<ArkBoardPsbtFacts, ArkWalletFailure>> inspectBoardPsbt({
    required String unfinalisedPsbt,
    required BitcoinNetwork network,
  }) async => Ok(
    ArkBoardPsbtFacts(
      unsignedTxid: 'c' * 64,
      finalised: finalised,
      nativeSegwitInputs: true,
      outputs: [
        ArkTransactionOutput(
          scriptPubkey: 'script',
          address: 'funding-address',
          amount: Sats.fromInt(1000),
        ),
      ],
    ),
  );
  @override
  Future<Result<ArkTransactionFacts, ArkWalletFailure>> inspectTransaction({
    required String transactionHex,
    required String signedPsbt,
    required BitcoinNetwork network,
  }) async => Ok(
    ArkTransactionFacts(
      txid: 'd' * 64,
      psbtTxid: 'd' * 64,
      inputs: [
        ArkTransactionInput(
          outpoint: wrongInputs ? FakeOpener.secondId : FakeOpener.firstId,
          amount: Sats.fromInt(10000),
          finalWitness: true,
        ),
      ],
      outputs: [
        ArkTransactionOutput(
          scriptPubkey: 'script',
          address: 'destination',
          amount: Sats.fromInt(10000 - fee),
        ),
      ],
      fee: Sats.fromInt(fee),
    ),
  );
}
