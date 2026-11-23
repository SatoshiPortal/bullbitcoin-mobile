class UnlockAttempt {
  final bool success;
  final int failedAttempts;
  final int timeout;

  UnlockAttempt({
    required this.success,
    required this.failedAttempts,
    required this.timeout,
  });
}
