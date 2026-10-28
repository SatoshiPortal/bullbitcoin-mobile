import 'transaction_position.dart';
import '../wallet_network_key.dart';
import 'wallet_transaction.dart';

enum WalletEvidenceLevel {
  localSourceState,
  walletSourceReported,
  headerChainVerified,
  inclusionVerified,
}

class WalletTransactionObservation {
  final WalletNetworkKey key;
  final WalletTransaction transaction;
  final DateTime observedAt;
  final DateTime? lastSuccessfulSyncAt;
  final String sourceKind;
  final Set<String> capabilities;
  final String? sourceTip;
  final bool complete;
  final WalletEvidenceLevel evidenceLevel;
  final int revision;
  final String fingerprint;

  const WalletTransactionObservation({
    required this.key,
    required this.transaction,
    required this.observedAt,
    required this.lastSuccessfulSyncAt,
    required this.sourceKind,
    required this.capabilities,
    required this.sourceTip,
    required this.complete,
    required this.evidenceLevel,
    required this.revision,
    required this.fingerprint,
  });

  TransactionPosition get position => transaction.position;
}
