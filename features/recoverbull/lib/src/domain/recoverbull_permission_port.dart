import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'recoverbull_failure.dart';

/// The configured runtime's permission, held by the application preferences.
abstract interface class RecoverBullPermissionPort {
  @useResult
  Future<Result<({bool granted, int revision}), RecoverBullFailure>>
  readPermission();

  @useResult
  Future<Result<void, RecoverBullFailure>> savePermission(bool granted);
}
