import 'package:meta/meta.dart';

import 'session_gate_event.dart';

@immutable
sealed class SessionGateEffect {
  const SessionGateEffect();
}

/// Read the current access state and answer [SessionAccessChanged].
final class SessionReadAccess extends SessionGateEffect {
  const SessionReadAccess();
}

/// Open the sign-in over the flow; answer [SessionSignInFinished] or
/// [SessionSignInCancelled].
final class SessionOpenSignIn extends SessionGateEffect {
  const SessionOpenSignIn();
}

/// Tell the user the session ended and leave the flow.
final class SessionShowEnded extends SessionGateEffect {
  const SessionShowEnded();
}

/// Leave the flow.
final class SessionCloseFlow extends SessionGateEffect {
  const SessionCloseFlow();
}
