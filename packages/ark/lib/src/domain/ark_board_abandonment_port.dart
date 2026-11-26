import 'package:primitives/primitives.dart';

import 'ark_wallet_failure.dart';
import 'entities/ark_account.dart';

/// Irreversible host-journal proof, never inferred from missing signatures.
final class ArkNeverSignedBoard {
  final ArkAccountId account;
  final String operationId;
  final String fundingTxid;
  final String address;
  final int keypairIndex;
  final int expiryHeight;
  final Sats grossAmount;
  final Sats netAmount;

  const ArkNeverSignedBoard({
    required this.account,
    required this.operationId,
    required this.fundingTxid,
    required this.address,
    required this.keypairIndex,
    required this.expiryHeight,
    required this.grossAmount,
    required this.netAmount,
  });
}

/// Privileged read-only authority over an exact never-signed Board tombstone.
/// A null result or failure supplies no abandonment evidence. Implementations
/// validate the durable closure receipt, original tuple and unsigned funding
/// output before returning a proof; no wallet lifecycle or signing locks are
/// entered. Existing stateless transaction codecs may use prepared native code.
abstract interface class ArkBoardAbandonmentPort {
  Future<Result<ArkNeverSignedBoard?, ArkWalletFailure>> readNeverSigned({
    required ArkAccountId account,
    required String operationId,
    required String fundingTxid,
  });
}
