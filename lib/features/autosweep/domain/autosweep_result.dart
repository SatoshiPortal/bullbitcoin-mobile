import 'package:bb_mobile/features/autosweep/domain/autosweep_error.dart';

enum AutosweepSkipReason {
  disabled,
  dust,
  inFlight,
  noDefaultWallet,
  selfSweep,
  feePolicy,
}

sealed class AutosweepResult {
  const AutosweepResult();
}

final class AutosweepSwept extends AutosweepResult {
  final String txid;

  const AutosweepSwept(this.txid);
}

final class AutosweepSkipped extends AutosweepResult {
  final AutosweepSkipReason reason;

  const AutosweepSkipped(this.reason);
}

final class AutosweepFailed extends AutosweepResult {
  final AutosweepError error;

  const AutosweepFailed(this.error);
}
