/// Opaque lifetime token for an operation-owned source wallet.
abstract interface class WalletSourceSession {
  bool get isClosed;
  void ensureOpen();
  void retire();
  void reactivate();
  Future<void> close();
}
