import 'package:transaction_sync/transaction_sync.dart';

/// A leased job: only the holder of [leaseToken] can complete or release it.
final class WalletSyncJobClaim {
  final String jobId;
  final WalletKey key;
  final String leaseToken;

  const WalletSyncJobClaim(this.jobId, this.key, this.leaseToken);
}
