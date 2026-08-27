/// Holds automatic backup publication while a destructive or restorative
/// operation owns the unified backup lifecycle.
abstract interface class WalletBackupLifecycleLease {
  void close();
}
