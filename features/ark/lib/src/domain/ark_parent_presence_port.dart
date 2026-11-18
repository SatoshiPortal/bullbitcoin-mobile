import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'ark_failure.dart';

abstract interface class ArkParentPresencePort {
  @useResult
  Future<Result<void, ArkFailure>> verifyPresent(Fingerprint parent);
}
