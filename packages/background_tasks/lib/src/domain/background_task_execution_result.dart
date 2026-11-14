enum BackgroundTaskExecutionStatus { success, retry, permanentFailure }

final class BackgroundTaskExecutionResult {
  final BackgroundTaskExecutionStatus status;

  const BackgroundTaskExecutionResult._(this.status);
  const BackgroundTaskExecutionResult.success()
    : this._(BackgroundTaskExecutionStatus.success);
  const BackgroundTaskExecutionResult.retry()
    : this._(BackgroundTaskExecutionStatus.retry);
  const BackgroundTaskExecutionResult.permanentFailure()
    : this._(BackgroundTaskExecutionStatus.permanentFailure);

  bool get shouldRetry => status == BackgroundTaskExecutionStatus.retry;
}
