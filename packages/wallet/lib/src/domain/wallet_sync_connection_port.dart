import 'wallet.dart';
import 'wallet_connection_port.dart';

/// Resolves the host's existing privacy/fallback policy for one operation.
abstract interface class WalletSyncConnectionPort {
  Future<T> runWithFallback<T>({
    required Network network,
    required Future<T> Function(WalletConnectionPort connection) operation,
  });

  /// Returns the safe legacy category only for a resolved fallback failure.
  String? failureCategory(Object error);
}
