import 'package:primitives/primitives.dart';

import '../../ark.dart';
import '../rust/api/payments.dart' as scuttle;
import '../rust/api/wallet.dart' as scuttle;
import 'ark_native_session.dart';

/// Scuttle reports the same `bark.*` subsystem names Bark does.
ArkMovementKind scuttleMovementKind(String subsystem) => switch (subsystem) {
  'bark.board' => ArkMovementKind.board,
  'bark.round' => ArkMovementKind.renewal,
  'bark.exit' => ArkMovementKind.exit,
  'bark.arkoor' ||
  'bark.offboard' ||
  'bark.lightning_send' => ArkMovementKind.payment,
  'bark.lightning_receive' => ArkMovementKind.lightningReceive,
  _ => ArkMovementKind.unknown,
};

ArkMovementStatus scuttleMovementStatus(scuttle.ScuttleMovementStatus status) =>
    switch (status) {
      scuttle.ScuttleMovementStatus.successful => ArkMovementStatus.successful,
      scuttle.ScuttleMovementStatus.pending => ArkMovementStatus.pending,
      scuttle.ScuttleMovementStatus.failed ||
      scuttle.ScuttleMovementStatus.canceled => ArkMovementStatus.failed,
    };

/// Includes the native Bitcoin transaction ID for offboards.
ArkMovement projectScuttleMovement(scuttle.ScuttleMovement movement) =>
    ArkMovement(
      id: movement.id.toString(),
      transactionId: movement.offboardTxid,
      kind: scuttleMovementKind(movement.subsystem),
      status: scuttleMovementStatus(movement.status),
      direction: switch ((movement.subsystem, movement.kind)) {
        ('bark.arkoor', 'receive') ||
        ('bark.lightning_receive', 'receive') => ArkMovementDirection.incoming,
        ('bark.arkoor', 'send') ||
        ('bark.lightning_send', 'send') => ArkMovementDirection.outgoing,
        _ => ArkMovementDirection.unknown,
      },
      amount: Sats.fromInt(movement.effectiveSats.abs()),
      positiveEffectiveAmount: movement.effectiveSats > 0,
      fee: Sats(movement.feeSats),
      createdAt: _seconds(movement.createdAt),
      completedAt: switch (movement.completedAt) {
        final at? => _seconds(at),
        null => null,
      },
    );

DateTime _seconds(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

DateTime scuttleRoundStart(BigInt seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000, isUtc: true);

/// A movement id as stored in `nativeReference` for Ark and bitcoin sends.
bool isScuttleMovementReference(String reference) =>
    RegExp(r'^[0-9]{1,10}$').hasMatch(reference);

/// Bark's mapping for a payment found in history. A failed movement can
/// follow consumed inputs, so it is never a proof of failure.
ArkOperationStatus scuttlePaymentMovementOutcome(
  scuttle.ScuttleMovementStatus status,
) => switch (status) {
  scuttle.ScuttleMovementStatus.successful => ArkOperationStatus.succeeded,
  scuttle.ScuttleMovementStatus.failed => ArkOperationStatus.outcomeUnknown,
  _ => ArkOperationStatus.pending,
};

ArkOperationStatus scuttleLightningSendOutcome(
  scuttle.ScuttleLightningSendStatus status,
) => switch (status) {
  scuttle.ScuttleLightningSendStatus.paid => ArkOperationStatus.succeeded,
  scuttle.ScuttleLightningSendStatus.inProgress => ArkOperationStatus.pending,
  scuttle.ScuttleLightningSendStatus.unknown =>
    ArkOperationStatus.outcomeUnknown,
};

/// Whether `parsed` offers a valid option of the destination's kind and agrees
/// with the requested amount. Throws like Bark's estimate otherwise.
scuttle.ScuttlePaymentKind validateScuttlePaymentRequest(
  ArkPaymentDestination destination,
  Sats amount,
  scuttle.ScuttlePaymentRequest parsed,
) {
  final wanted = switch (destination.kind) {
    ArkDestinationKind.ark => scuttle.ScuttlePaymentKind.ark,
    ArkDestinationKind.bolt11 => scuttle.ScuttlePaymentKind.bolt11,
    ArkDestinationKind.bitcoin => scuttle.ScuttlePaymentKind.bitcoin,
  };
  final fixed = parsed.amountSats;
  if (!parsed.options.any((o) => o.valid && o.kind == wanted) ||
      (fixed != null && fixed != amount.value)) {
    throw const ArkBoundaryException(
      ArkValidationFailure(ArkFailureReason.validation),
    );
  }
  return wanted;
}

/// Checks a fee estimate the way Bark's estimate does and returns the VTXOs it
/// spends. A renewal must spend exactly the requested VTXOs.
List<String> validateScuttleEstimate({
  required scuttle.ScuttleFeeEstimate estimate,
  required int tip,
  required List<ArkVtxo> vtxos,
  required Sats? spendable,
  List<String>? renewalIds,
}) {
  if (estimate.netSats <= BigInt.zero) {
    throw const ArkBoundaryException(
      ArkValidationFailure(ArkFailureReason.validation),
    );
  }
  final selected = estimate.vtxoIds;
  if (selected.isEmpty ||
      selected.toSet().length != selected.length ||
      !selected.every(
        (id) => vtxos.any((v) => v.id == id && v.eligibleAt(tip)),
      )) {
    throw const ArkBoundaryException(
      ArkValidationFailure(ArkFailureReason.invalidSelection),
    );
  }
  if (renewalIds != null &&
      (selected.toSet().difference(renewalIds.toSet()).isNotEmpty ||
          renewalIds.toSet().difference(selected.toSet()).isNotEmpty)) {
    throw const ArkBoundaryException(
      ArkValidationFailure(ArkFailureReason.invalidSelection),
    );
  }
  if (spendable == null || estimate.grossSats > spendable.value) {
    throw const ArkBoundaryException(ArkInsufficientFundsFailure());
  }
  return selected;
}

/// bark0.8.1 VTXO dust is 330 sats, applied to Ark-bound amounts.
const scuttleVtxoDust = 330;

bool isScuttleDust(BigInt net) => net < BigInt.from(scuttleVtxoDust);

/// Renewal reconciliation by round id. Bark proves success from a refresh
/// movement's inputs and outputs, which the bridge does not expose: here the
/// round must be gone from the pending rounds, every renewed VTXO spent, and a
/// successful round movement recorded. Anything less is not a proof.
ArkOperationStatus? scuttleRenewalOutcome({
  required String? reference,
  required List<String> actualIds,
  required List<scuttle.ScuttleRoundState> rounds,
  required List<scuttle.ScuttleVtxo> vtxos,
  required List<scuttle.ScuttleMovement> history,
}) {
  final id = reference == null ? null : int.tryParse(reference);
  if (id == null || actualIds.isEmpty) return null;
  if (rounds.any((round) => round.id == id)) return null;
  final states = {for (final v in vtxos) v.id: v.state};
  if (actualIds.every((v) => states[v] == scuttle.ScuttleVtxoState.spent) &&
      history.any(
        (m) =>
            m.subsystem == 'bark.round' &&
            m.kind == 'refresh' &&
            m.status == scuttle.ScuttleMovementStatus.successful,
      )) {
    return ArkOperationStatus.succeeded;
  }
  return null;
}
