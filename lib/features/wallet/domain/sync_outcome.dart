enum SyncOutcomeKind { active, idle, rateLimited }

class SyncOutcome {
  const SyncOutcome._(this.kind, {this.retryAfter, this.failure});

  const SyncOutcome.active() : this._(SyncOutcomeKind.active);
  const SyncOutcome.idle() : this._(SyncOutcomeKind.idle);
  const SyncOutcome.rateLimited({Duration? retryAfter, Object? failure})
    : this._(
        SyncOutcomeKind.rateLimited,
        retryAfter: retryAfter,
        failure: failure,
      );

  final SyncOutcomeKind kind;
  final Duration? retryAfter;
  final Object? failure;
}
