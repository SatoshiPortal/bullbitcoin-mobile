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
  Future<String> registerBoard(ArkRegisterBoard submission);
  Future<ArkClaimTransaction> prepareClaim(ArkQuote quote);
  Future<String> broadcast(String rawTransaction);
  Future<ArkReceiveDestination> receive(ArkReceiveRequest request);
  Future<ArkOperation?> reconcile(ArkOperation operation);
  void close();
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
