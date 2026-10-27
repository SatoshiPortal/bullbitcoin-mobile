import '../wallet_network_key.dart';
import '../wallet_source_registration.dart';
import 'wallet_transaction.dart';
import 'wallet_transaction_observation.dart';

class WalletSourceObservation {
  final WalletNetworkKey key;
  final WalletSourceRegistration registration;
  final List<WalletTransaction> transactions;
  final Set<String> capabilities;
  final String? sourceTip;
  final bool complete;
  final WalletEvidenceLevel evidenceLevel;

  const WalletSourceObservation({
    required this.key,
    required this.registration,
    required this.transactions,
    this.capabilities = const {},
    this.sourceTip,
    this.complete = true,
    this.evidenceLevel = WalletEvidenceLevel.localSourceState,
  });
}
