import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'ark_failure.dart';

/// Must consult the complete historical registry, including revoked records,
/// for English BIP39/12/index11811 only. Unknown or incomplete means Err.
abstract interface class ArkChildCollisionPort {
  @useResult
  Future<Result<bool, ArkFailure>> hasCollision(Fingerprint parent);
}
