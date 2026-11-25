/// Which way the value travels relative to this device.
///
/// Outgoing scenes move away from the user (up and out); incoming scenes play
/// the same diagram mirrored so the value travels down toward the user.
enum BullPaymentDirection { outgoing, incoming }

/// State of the refund of a failed Boltz swap whose funds return to the
/// source: [available] while the refund can still be broadcast, [done] once
/// the refund transaction exists.
enum BullPaymentRefund { available, done }

/// How the status the payment is currently in reads.
///
/// [active]: work is in progress. [broadcast]: a transaction is on the network
/// and waits for its confirmation. [held]: the outcome is uncertain or the
/// payment waits on something else; neither progressing nor failed.
enum BullPaymentStepState { active, broadcast, held }

/// The statuses of one payment, in order, supplied by its owner.
///
/// One step is one status the caller can actually observe (for example a
/// broadcast transaction, then its confirmation). The payment is in step
/// [completed]; it is complete only once the last status is reached, which
/// the owner reports through the success phase. The kit never advances a
/// step on a timer.
final class BullPaymentProgress {
  /// Translated, short labels in protocol order.
  final List<String> steps;

  /// Number of statuses already behind the payment, from 0 to
  /// `steps.length`: the index of the status it is in.
  final int completed;

  /// How the current status reads.
  final BullPaymentStepState currentState;

  /// Index of a step that failed, if any. Steps after it are not reached.
  final int? failedAt;

  /// Index of a step the protocol bypassed without failing the payment (for
  /// example a Payjoin whose original transaction was broadcast instead).
  final int? skippedAt;

  /// Refund of a failed swap; drawn as a return trace to the source.
  final BullPaymentRefund? refund;

  /// Observed progress, from 0 to 1, of the awaited step (for example the
  /// share of an exit's timelock already elapsed). Null means the step is
  /// awaited with no measurable progress: scenes show an indeterminate pulse.
  /// Real data only, never an estimate from the clock.
  final double? currentFraction;

  BullPaymentProgress({
    required List<String> steps,
    required this.completed,
    this.currentState = BullPaymentStepState.active,
    this.failedAt,
    this.skippedAt,
    this.refund,
    this.currentFraction,
  }) : steps = List.unmodifiable(steps),
       assert(steps.isNotEmpty),
       assert(completed >= 0 && completed <= steps.length),
       assert(failedAt == null || (failedAt >= 0 && failedAt < steps.length)),
       assert(
         skippedAt == null || (skippedAt >= 0 && skippedAt < steps.length),
       ),
       assert(
         currentFraction == null ||
             (currentFraction >= 0 && currentFraction <= 1),
       );

  int get total => steps.length;

  int get remaining => total - completed;

  bool get isComplete => completed == total;

  /// The step currently awaited, or null when every step is complete.
  int? get current => isComplete ? null : completed;

  @override
  bool operator ==(Object other) =>
      other is BullPaymentProgress &&
      other.completed == completed &&
      other.currentState == currentState &&
      other.failedAt == failedAt &&
      other.skippedAt == skippedAt &&
      other.refund == refund &&
      other.currentFraction == currentFraction &&
      _sameSteps(other.steps, steps);

  @override
  int get hashCode => Object.hash(
    completed,
    currentState,
    failedAt,
    skippedAt,
    refund,
    Object.hashAll(steps),
  );

  static bool _sameSteps(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
