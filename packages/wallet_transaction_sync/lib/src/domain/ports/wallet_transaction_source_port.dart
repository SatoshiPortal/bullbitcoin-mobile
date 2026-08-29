import '../entities/wallet_transaction.dart';
import '../entities/wallet_transaction_observation.dart';
import '../wallet_network_key.dart';
import '../wallet_source_registration.dart';
import '../wallet_transaction_sync_failure.dart';
import 'package:primitives/primitives.dart';
import '../../wallet_source_session.dart';
import 'package:meta/meta.dart';

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

abstract interface class WalletTransactionSourcePort {
  @useResult
  Future<Result<WalletSourceObservation, WalletTransactionSyncFailure>>
  refreshLocal(
    WalletSourceRegistration registration,
    WalletSourceSession session,
  );
  @useResult
  Future<Result<WalletSourceObservation, WalletTransactionSyncFailure>>
  synchronize(
    WalletSourceRegistration registration,
    WalletSourceSession session, {
    required bool discover,
  });

  /// Deletes the persisted source state for [key]. [registration] is provided
  /// when the deletion runs inside a registration-carrying operation (resume
  /// of a pending deletion); without it the adapter may rely on
  /// process-local knowledge of the key and fail typed when it has none.
  @useResult
  Future<Result<void, WalletTransactionSyncFailure>> delete(
    WalletNetworkKey key,
    WalletSourceSession session, {
    WalletSourceRegistration? registration,
  });
}
