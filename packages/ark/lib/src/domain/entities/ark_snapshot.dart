import 'package:primitives/primitives.dart';

import 'ark_account.dart';
import 'ark_operation.dart';

enum ArkVtxoState { spendable, locked, spent, exited, unknown, abandonedBoard }

enum ArkRecoveryStatus { unknown, notRun, complete, incomplete, failed }

enum ArkRenewalStatus { unknown, current, due, delegated, failed }

enum ArkExitStatus {
  unknown,
  none,
  pending,
  claimable,
  submitted,
  claimed,
  failed,
}

enum ArkObligationStatus { unknown, none, present }

final class ArkVtxo {
  final String id;
  final Sats amount;
  final int expiryHeight;
  final ArkVtxoState state;
  final String? anchor;
  final bool pendingRound;

  ArkVtxo({
    required this.id,
    required this.amount,
    required this.expiryHeight,
    required this.state,
    this.anchor,
    this.pendingRound = false,
  }) {
    if (id.isEmpty || expiryHeight < 0) throw ArgumentError('Invalid VTXO');
  }

  bool eligibleAt(int tipHeight) =>
      state == ArkVtxoState.spendable &&
      !pendingRound &&
      expiryHeight > tipHeight;
  bool renewalDueAt(int tipHeight, int threshold) =>
      eligibleAt(tipHeight) && expiryHeight - tipHeight < threshold;
}

final class ArkMovement {
  final String id;
  final ArkMovementKind kind;
  final ArkMovementStatus status;

  /// Native movement direction; incoming does not prove an external sender.
  final ArkMovementDirection direction;
  final Sats? amount;

  /// True only when the native signed effective balance was positive.
  final bool positiveEffectiveAmount;
  final Sats? fee;
  final DateTime? createdAt;
  final List<String> inputVtxoIds;
  final List<String> outputVtxoIds;
  final String? transactionId;

  /// Where the funds went, for a movement that sent them out of Ark.
  final List<String> sentTo;

  /// Where the funds arrived, for a movement that brought them into Ark.
  final List<String> receivedOn;

  /// When the movement settled; null while it is pending.
  final DateTime? completedAt;
  ArkMovement({
    required this.id,
    required this.kind,
    required this.status,
    this.direction = ArkMovementDirection.unknown,
    this.amount,
    this.positiveEffectiveAmount = false,
    this.fee,
    this.createdAt,
    List<String> inputVtxoIds = const [],
    List<String> outputVtxoIds = const [],
    this.transactionId,
    List<String> sentTo = const [],
    List<String> receivedOn = const [],
    this.completedAt,
  }) : inputVtxoIds = List.unmodifiable(inputVtxoIds),
       outputVtxoIds = List.unmodifiable(outputVtxoIds),
       sentTo = List.unmodifiable(sentTo),
       receivedOn = List.unmodifiable(receivedOn);

  /// A Board that failed with nothing reaching Ark: its review was left
  /// before funding was signed, so no funds moved. An unknown amount, or any
  /// amount that did reach Ark, is never treated as unfunded.
  bool get isUnfundedBoard =>
      kind == ArkMovementKind.board &&
      status == ArkMovementStatus.failed &&
      amount?.value == BigInt.zero;
}

final class ArkServerInfo {
  final String publicKey;
  final int? roundIntervalSeconds;
  final int? vtxoLifetimeBlocks;
  final Sats? minimumBoard;
  final Sats? maximumVtxo;
  final int? boardConfirmations;
  const ArkServerInfo({
    required this.publicKey,
    this.roundIntervalSeconds,
    this.vtxoLifetimeBlocks,
    this.minimumBoard,
    this.maximumVtxo,
    this.boardConfirmations,
  });
}

/// Missing observations stay nullable; unknown obligations fail closed.
final class ArkSnapshot {
  final ArkAccountId account;
  final int revision;
  final DateTime observedAt;
  final int? tipHeight;
  final bool stale;
  final Sats? spendable;
  final Sats? pending;
  final Sats? confirmedReserve;
  final List<ArkVtxo> vtxos;
  final List<ArkMovement> movements;
  final List<ArkOperation> operations;
  final List<ArkExit> exitDetails;
  final List<ArkPendingBoard> pendingBoards;
  final ArkSectionCompleteness vtxoCompleteness;
  final ArkServerInfo? serverInfo;
  final ArkRenewalStatus renewal;
  final ArkExitStatus exits;
  final ArkRecoveryStatus recovery;
  final ArkObligationStatus obligations;

  /// Board-only pending balance after proved exclusions; null when unobserved.
  final Sats? pendingBoardBalance;
  final int? pendingBoardCount;
  final int? pendingLightningCount;
  final int? pendingRoundCount;
  final String? reserveAddress;
  final bool usingFallback;

  ArkSnapshot({
    required this.account,
    required this.revision,
    required this.observedAt,
    this.tipHeight,
    this.stale = true,
    this.spendable,
    this.pending,
    this.confirmedReserve,
    List<ArkVtxo> vtxos = const [],
    List<ArkMovement> movements = const [],
    List<ArkOperation> operations = const [],
    List<ArkExit> exitDetails = const [],
    List<ArkPendingBoard> pendingBoards = const [],
    this.vtxoCompleteness = ArkSectionCompleteness.unknown,
    this.serverInfo,
    this.renewal = ArkRenewalStatus.unknown,
    this.exits = ArkExitStatus.unknown,
    this.recovery = ArkRecoveryStatus.unknown,
    this.obligations = ArkObligationStatus.unknown,
    this.pendingBoardBalance,
    this.pendingBoardCount,
    this.pendingLightningCount,
    this.pendingRoundCount,
    this.reserveAddress,
    this.usingFallback = false,
  }) : vtxos = List.unmodifiable(vtxos),
       movements = List.unmodifiable(movements),
       operations = List.unmodifiable(operations),
       exitDetails = List.unmodifiable(exitDetails),
       pendingBoards = List.unmodifiable(pendingBoards) {
    final height = tipHeight;
    if (revision < 0 || (height != null && height < 0)) {
      throw ArgumentError('Invalid snapshot revision or height');
    }
  }

  bool get vtxoInventoryComplete =>
      vtxoCompleteness == ArkSectionCompleteness.complete;

  /// Safe for disabling/new-route policy; never safe for deleting custody.
  bool get hasFundsOrObligations =>
      stale ||
      !vtxoInventoryComplete ||
      obligations != ArkObligationStatus.none ||
      recovery != ArkRecoveryStatus.complete ||
      [
        spendable,
        pending,
        confirmedReserve,
      ].any((value) => value == null || value.value > BigInt.zero) ||
      vtxos.any(
        (v) => v.state != ArkVtxoState.spent && v.state != ArkVtxoState.exited,
      ) ||
      exits != ArkExitStatus.none ||
      operations.any(
        (operation) =>
            operation.status != ArkOperationStatus.succeeded &&
            operation.status != ArkOperationStatus.failed,
      ) ||
      [
        pendingBoardCount,
        pendingLightningCount,
        pendingRoundCount,
      ].any((count) => count == null || count > 0);
}

final class ArkPassOutcome {
  final ArkSnapshot snapshot;
  final List<String> failedStages;
  final List<String> submittedRounds;
  final Set<ArkStage> completedStages;
  final Set<ArkStage> failedStageKinds;
  ArkPassOutcome({
    required this.snapshot,
    List<String> failedStages = const [],
    List<String> submittedRounds = const [],
    Set<ArkStage> completedStages = const {},
    Set<ArkStage> failedStageKinds = const {},
  }) : failedStages = List.unmodifiable(failedStages),
       submittedRounds = List.unmodifiable(submittedRounds),
       completedStages = Set.unmodifiable(completedStages),
       failedStageKinds = Set.unmodifiable(failedStageKinds);
}

/// Section evidence is independent of whether a cached balance exists.
enum ArkStage {
  ark,
  lightning,
  rounds,
  boards,
  server,
  onchain,
  vtxos,
  exits,
  renewal,
}

enum ArkSectionCompleteness { unknown, complete, incomplete }

final class ArkExit {
  final String id;
  final Sats amount;
  final ArkExitStatus status;
  final int? claimableHeight;
  final String? claimTxid;
  const ArkExit({
    required this.id,
    required this.amount,
    required this.status,
    this.claimableHeight,
    this.claimTxid,
  });
}

final class ArkPendingBoard {
  final String vtxoId;
  final String fundingTxid;
  final Sats amount;
  final int? expiryHeight;
  const ArkPendingBoard({
    required this.vtxoId,
    required this.fundingTxid,
    required this.amount,
    this.expiryHeight,
  });
}

enum ArkMovementKind {
  board,
  payment,
  renewal,
  exit,
  lightningReceive,
  unknown,
}

enum ArkMovementStatus { pending, successful, failed, unknown }

enum ArkMovementDirection { incoming, outgoing, unknown }
