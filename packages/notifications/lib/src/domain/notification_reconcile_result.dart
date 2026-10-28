final class NotificationReconcileResult {
  final int pendingCount;

  /// Topics the foreground has not recorded yet: nothing is enqueued for
  /// them, so a wallet's history is never announced as new payments.
  final int skippedTopicCount;

  const NotificationReconcileResult({
    required this.pendingCount,
    this.skippedTopicCount = 0,
  });
}
