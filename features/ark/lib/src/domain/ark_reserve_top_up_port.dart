import 'package:ark/ark.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'ark_failure.dart';

/// Optional host capability: funds the Ark on-chain fee reserve from the
/// Secure Bitcoin wallet the account belongs to, so an emergency exit can
/// pay its broadcast fees.
abstract interface class ArkReserveTopUpPort {
  /// Sends [amount] to the reserve [address]; the broadcast txid. A failure
  /// means nothing was broadcast, except [ArkSubmissionUncertainFailure].
  @useResult
  Future<Result<String, ArkFailure>> topUp(
    ArkAccountId account, {
    required String address,
    required Sats amount,
  });
}
