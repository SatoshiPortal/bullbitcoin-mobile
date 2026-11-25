import '../../ark.dart';

/// Host effects serialized with Ark account writes.
///
/// Implementations must not call back into the client while the writer is held.
abstract interface class ArkExitObserverPort {
  Future<void> observe(ArkPassOutcome outcome);

  Future<void> claimAdmitted(ArkAccountId account, ArkOperation claim);
}
