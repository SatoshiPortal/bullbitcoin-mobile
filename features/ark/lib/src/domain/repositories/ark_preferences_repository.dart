import 'package:ark/ark.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';

/// Off only stops new routes. It never deletes the account or its obligations.
abstract interface class ArkPreferencesRepository {
  @useResult
  Future<Result<bool, ArkFailure>> isEnabled(ArkAccountId account);
  @useResult
  Future<Result<void, ArkFailure>> setEnabled(
    ArkAccountId account,
    bool enabled,
  );
}
