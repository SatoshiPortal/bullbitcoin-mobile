/// Opaque lifetime token for an operation-owned source wallet.
abstract interface class WalletSourceSession {
  bool get isClosed;
  void ensureOpen();
  void retire();
  void reactivate();
  Future<void> close();
}

/// A native resource can outlive the callback's bounded wait. The coordinator reports the callback result, but retains exclusion until every hold settles. A hold must complete successfully only after actual native termination.
abstract interface class WalletSourceLifetimeSession
    implements WalletSourceSession {
  void retainUntil(Future<void> termination);
}
