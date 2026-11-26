import 'package:meta/meta.dart';
import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import 'ark_failure.dart';

/// Wallet-owned selection of an eligible software parent and captured network.
/// No application wallet type crosses the module boundary.
abstract interface class ArkAccountSelectionPort {
  @useResult
  Future<Result<ArkAccountConfig, ArkFailure>> selectedAccount();
}
