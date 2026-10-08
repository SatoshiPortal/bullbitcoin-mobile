abstract interface class RecoverBullLifecyclePort {
  Future<void> markStored();
  Future<void> markVerified();
}
