import '../wallet_source_registration.dart';
import '../../wallet_source_operation_coordinator.dart';

class SynchronizeWalletRequest {
  final WalletSourceRegistration registration;
  final WalletOperationPriority priority;
  const SynchronizeWalletRequest(
    this.registration, {
    this.priority = WalletOperationPriority.foreground,
  });
}
