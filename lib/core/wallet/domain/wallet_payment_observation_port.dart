import 'package:transaction_sync/transaction_sync.dart';

/// Records what the user can see after a foreground sync, so a background
/// run announces only payments received afterwards.
abstract interface class WalletPaymentObservationPort {
  Future<void> recordSeen(WalletNetworkKey key, List<String> txids);
}
