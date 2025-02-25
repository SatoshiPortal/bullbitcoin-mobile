abstract class PinCodeRepository {
  Future<bool> isPinCodeSet();
  Future<void> setPinCode(String pinCode);
  Future<bool> verifyPinCode(String pinCode);
  Future<void> deletePinCode();
}
