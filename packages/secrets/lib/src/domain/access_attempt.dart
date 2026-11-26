/// Result of an access attempt or a read of the current cooldown.
final class AccessAttempt {
  final bool accepted;
  final int failedAttempts;
  final DateTime? lockedUntil;
  final Duration remaining;

  const AccessAttempt({
    required this.accepted,
    required this.failedAttempts,
    required this.lockedUntil,
    required this.remaining,
  });
}
