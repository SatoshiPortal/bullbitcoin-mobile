/// Durable state shared by every credential in the inventory.
final class AccessAttempt {
  final bool accepted;
  final int failedAttempts;
  final DateTime? lockedUntil;

  const AccessAttempt({
    required this.accepted,
    required this.failedAttempts,
    required this.lockedUntil,
  });
}
