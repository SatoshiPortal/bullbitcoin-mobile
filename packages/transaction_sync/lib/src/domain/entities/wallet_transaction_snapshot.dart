import '../wallet_network_key.dart';
import 'wallet_transaction.dart';
import 'wallet_transaction_observation.dart';

class WalletTransactionSnapshot {
  final WalletNetworkKey key;
  final int revision;
  final String contentFingerprint;
  final List<WalletTransaction> transactions;
  final DateTime observedAt;
  final DateTime? lastSuccessfulSyncAt;
  final String sourceKind;
  final Set<String> capabilities;
  final String? sourceTip;
  final bool complete;
  final WalletEvidenceLevel evidenceLevel;
  final Map<String, WalletTransaction> _byTxid;

  WalletTransactionSnapshot({
    required this.key,
    required this.revision,
    required this.contentFingerprint,
    required List<WalletTransaction> transactions,
    required this.observedAt,
    required this.lastSuccessfulSyncAt,
    required this.sourceKind,
    required Set<String> capabilities,
    required this.sourceTip,
    required this.complete,
    required this.evidenceLevel,
  }) : transactions = List.unmodifiable(transactions),
       capabilities = Set.unmodifiable(capabilities),
       _byTxid = Map.unmodifiable({
         for (final transaction in transactions) transaction.txid: transaction,
       });

  WalletTransactionObservation? lookup(String txid) {
    final transaction = _byTxid[txid];
    if (transaction == null) return null;
    return WalletTransactionObservation(
      key: key,
      transaction: transaction,
      observedAt: observedAt,
      lastSuccessfulSyncAt: lastSuccessfulSyncAt,
      sourceKind: sourceKind,
      capabilities: capabilities,
      sourceTip: sourceTip,
      complete: complete,
      evidenceLevel: evidenceLevel,
      revision: revision,
      fingerprint: contentFingerprint,
    );
  }
}
