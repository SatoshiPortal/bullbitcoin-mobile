import '../../wallet_source_session.dart';
import '../wallet_source_registration.dart';
import '../../wallet_source_operation_coordinator.dart';

class SynchronizeWalletRequest {
  final WalletSourceRegistration registration;

  /// Shell integration only: reuse an already admitted operation, never nest the same-key coordinator. The caller retains session ownership.
  final WalletSourceSession? session;
  final WalletOperationPriority priority;

  /// False for a headless run: a wallet that was never scanned is refused
  /// with `InitialScanRequiredFailure` instead of scanned.
  final bool allowInitialScan;
  const SynchronizeWalletRequest(
    this.registration, {
    this.priority = WalletOperationPriority.foreground,
    this.allowInitialScan = true,
    this.session,
  });
}
