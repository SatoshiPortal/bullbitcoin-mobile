import '../wallet_source_registration.dart';
import '../../wallet_source_operation_coordinator.dart';

class SynchronizeWalletRequest {
  final WalletSourceRegistration registration;
  final WalletOperationPriority priority;

  /// False for a headless run: a wallet that was never scanned is refused
  /// with `InitialScanRequiredFailure` instead of scanned.
  final bool allowInitialScan;
  const SynchronizeWalletRequest(
    this.registration, {
    this.priority = WalletOperationPriority.foreground,
    this.allowInitialScan = true,
  });
}
