abstract class FailedUnlockAttemptsRepository {
  Future<void> setFailedUnlockAttempts(int attempts);
  Future<int> getFailedUnlockAttempts();
}
