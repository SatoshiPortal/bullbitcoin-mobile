import '../wallet_network_key.dart';
import '../wallet_transaction_sync_failure.dart';

enum BitcoinSyncPhase {
  findingPeers,
  checkingBlocks,
  downloadingTransactions,
  done,
}

final class BitcoinSyncProgress {
  final WalletNetworkKey key;
  final BitcoinSyncPhase phase;
  final double? fraction;
  final int? reachedHeight;
  final int? targetHeight;
  final int? startHeight;
  final bool isRecovery;
  final int? operationId;
  final String? policyFingerprint;
  final DateTime? startedAt;
  final int? connectedPeers;
  final WalletTransactionSyncFailure? failure;

  const BitcoinSyncProgress({
    required this.key,
    required this.phase,
    this.fraction,
    this.reachedHeight,
    this.targetHeight,
    this.startHeight,
    this.isRecovery = false,
    this.operationId,
    this.policyFingerprint,
    this.startedAt,
    this.connectedPeers,
    this.failure,
  });
}

abstract interface class BitcoinSyncProgressRepository {
  Stream<BitcoinSyncProgress> watchBitcoinSyncProgress(WalletNetworkKey key);
}
