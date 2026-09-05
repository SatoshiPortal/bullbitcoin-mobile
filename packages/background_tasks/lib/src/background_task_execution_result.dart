enum BackgroundTaskExecutionStatus { success, retry, permanentFailure }

final class BackgroundTaskExecutionResult {
  final BackgroundTaskExecutionStatus status;
  final Object? failure;

  const BackgroundTaskExecutionResult._(this.status, [this.failure]);
  const BackgroundTaskExecutionResult.success()
    : this._(BackgroundTaskExecutionStatus.success);
  const BackgroundTaskExecutionResult.retry([Object? failure])
    : this._(BackgroundTaskExecutionStatus.retry, failure);
  const BackgroundTaskExecutionResult.permanentFailure([Object? failure])
    : this._(BackgroundTaskExecutionStatus.permanentFailure, failure);

  bool get shouldRetry => status == BackgroundTaskExecutionStatus.retry;
}
