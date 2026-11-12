import 'package:bb_mobile/features/broadcast_signed_tx/domain/broadcast_signed_tx_failure.dart';
import 'package:bb_mobile/features/send/public/broadcast_failure.dart';

/// What the user is told when a broadcast fails, from the send feature's
/// diagnostic [category]. Only a connection failure blames the connection.
BroadcastSignedTxFailure broadcastSignedTxFailureFor(
  BroadcastFailureCategory category,
) => switch (category) {
  BroadcastFailureCategory.connection => const BroadcastFailedFailure(),
  BroadcastFailureCategory.alreadyInChain =>
    const TransactionAlreadyInChainFailure(),
  BroadcastFailureCategory.rejected => const TransactionRejectedFailure(),
  BroadcastFailureCategory.authorization =>
    const BroadcastNetworkNotEnabledFailure(),
  BroadcastFailureCategory.unexpected => const BroadcastOutcomeUnknownFailure(),
};
