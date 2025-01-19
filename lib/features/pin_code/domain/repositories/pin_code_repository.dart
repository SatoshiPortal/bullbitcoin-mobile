abstract class PinCodeRepository {
  Future<bool> isPinCodeSet();
  Future<void> createPinCode(String pinCode);
  Future<bool> checkPinCode(String pinCode);
  Future<void> updatePinCode({
    required String oldPinCode,
    required String newPinCode,
  });
  Future<void> setFailedUnlockAttempts(int attempts);
  Future<int> getFailedUnlockAttempts();
}
