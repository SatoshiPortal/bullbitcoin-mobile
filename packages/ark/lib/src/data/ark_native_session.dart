import 'package:primitives/primitives.dart';

import '../../ark.dart';

/// Internal seam used by lifecycle tests. No native dependency in its types.
abstract interface class ArkNativeOpener {
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
  });
  bool datadirExists(String datadir);
}

abstract interface class ArkStageRunner {
  Future<T> run<T>(String name, Future<T> Function() action);
}

final class ArkStageDeferred implements Exception {
  const ArkStageDeferred();
}

final class ArkBoundaryException implements Exception {
  final ArkWalletFailure failure;
  const ArkBoundaryException(this.failure);
}

abstract interface class ArkNativeSession {
  Future<ArkSnapshot> observe({
    required ArkAccountId account,
    required int revision,
    required DateTime now,
    required Uri chainSource,
    required List<ArkOperation> operations,
    required ArkRecoveryStatus previousRecovery,
  });
  Future<void> synchronizeStage(String name);
  Future<ArkQuote> estimate({
    required ArkSnapshot snapshot,
    required ArkQuoteRequest request,
    required String id,
    required Uri chainSource,
    required int configGeneration,
    required DateTime now,
  });
  Future<ArkOperation> execute(ArkQuote quote, String operationId);
  Future<List<String>> renewalCandidates();
  Future<String> reserveAddress();
  Future<ArkBoardFundingDetails> boardFunding();
  Future<String> registerBoard(
    ArkRegisterBoard submission,
    ArkBoardFundingDetails funding,
  );
  Future<ArkClaimTransaction> prepareClaim(ArkQuote quote);
  Future<String> broadcast(String rawTransaction);
  Future<ArkReceiveDestination> receive(ArkReceiveRequest request);

  /// When the Ark server schedules the next round, as reported by the server
  /// itself; each call is a live server request.
  Future<DateTime> nextRoundStart();
  Future<ArkOperation?> reconcile(ArkOperation operation);

  /// Releases all native handles before the account writer can be released.
  Future<void> close();
}

/// Native backend that can price a board independently of VTXO freshness.
abstract interface class ArkNativeLiveBoardSession
    implements ArkNativeSession {}

/// Imports one existing payment into the dedicated regtest exit reserve.
abstract interface class ArkNativeExitReserveSession
    implements ArkNativeSession {
  Future<bool> verifyInitialExitReserve(
    ArkExitReserveFunding funding,
    String reserveAddress,
  );
  Future<bool> importInitialExitReserve(
    ArkExitReserveFunding funding,
    String reserveAddress,
  );
}

typedef ArkExitCpfpEvidence = ({String txid, String raw, Sats fee});
typedef ArkExitCpfpStep = ({String vtxoId, String parentTxid});
typedef ArkExitCpfpCandidate = ({
  ArkExitCpfpEvidence evidence,
  List<String> reserveInputs,
});

abstract interface class ArkNativeExitCpfpSession implements ArkNativeSession {
  Future<List<ArkExitCpfpStep>> dueExitCpfp(List<String> exitIds);
  Future<ArkExitCpfpCandidate> prepareExitCpfp(
    ArkExitCpfpStep step,
    FeeRate rate,
    Sats remainingFee,
  );
  Future<void> deliverExitCpfp(
    ArkExitCpfpStep step,
    ArkExitCpfpEvidence evidence,
  );
  Future<bool> importExitCpfpChange(ArkExitCpfpEvidence evidence);
}

final class ArkClaimTransaction {
  final String rawTransaction;
  final String signedPsbt;
  final List<String> actualIds;
  final List<String> skippedIds;
  final Map<String, String> inputAmounts;
  final String fee;
  ArkClaimTransaction({
    required this.rawTransaction,
    required this.signedPsbt,
    required this.actualIds,
    required this.skippedIds,
    required this.inputAmounts,
    required this.fee,
  });
}
