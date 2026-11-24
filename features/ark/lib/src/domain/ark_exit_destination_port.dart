import 'package:ark/ark.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'ark_failure.dart';

/// Optional host capability: where an emergency exit can send its funds in
/// the user's own wallet.
abstract interface class ArkExitDestinationPort {
  /// A fresh, unused receive address of the Secure Bitcoin wallet that
  /// [account] belongs to. Each call may reveal a new address.
  @useResult
  Future<Result<String, ArkFailure>> secureBitcoinAddress(ArkAccountId account);
}
