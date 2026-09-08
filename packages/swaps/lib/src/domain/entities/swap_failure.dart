import 'package:primitives/primitives.dart';

/// The swap engine's modeled failures — one sealed family, per the
/// project-wide error convention: variants carry typed data, the catch-all
/// carries only a `logMessage` that is logged at the boundary and never
/// shown to a user; translation lives in an app-side presentation
/// extension.
sealed class SwapsFailure extends Failure {
  const SwapsFailure([super.logMessage]);
}

/// No default bitcoin wallet seed is available to derive the swap master
/// key (watch-only, hardware-only or pre-onboarding wallet) — restore and
/// rescue cannot run.
final class SwapsMasterKeyUnavailableFailure extends SwapsFailure {
  const SwapsMasterKeyUnavailableFailure([super.logMessage]);
}

/// The backend knows the swap but could not rebuild it (skipped during
/// restore, or beyond the key gap limit).
final class SwapsNotRestorableFailure extends SwapsFailure {
  const SwapsNotRestorableFailure([super.logMessage]);
}

/// The refund's timelock has not passed yet; retrying later succeeds.
final class SwapsRefundNotFinalFailure extends SwapsFailure {
  const SwapsRefundNotFinalFailure([super.logMessage]);
}

/// No configured server (electrum or the swap backend) was reachable.
final class SwapsNetworkFailure extends SwapsFailure {
  const SwapsNetworkFailure([super.logMessage]);
}

/// The catch-all. The raw reason lives in `logMessage` for diagnosis only.
final class SwapsUnexpectedFailure extends SwapsFailure {
  const SwapsUnexpectedFailure([super.logMessage]);
}

/// Maps a raw engine error to its modeled failure. The raw text goes into
/// `logMessage`; the boundary logs it, the UI never sees it.
SwapsFailure classifySwapsFailure(Object error) {
  final message = error.toString();
  final lower = message.toLowerCase();
  if (lower.contains('no default bitcoin wallet seed')) {
    return SwapsMasterKeyUnavailableFailure(message);
  }
  if (lower.contains('not returned by boltz restore') ||
      lower.contains('could not be rebuilt from restore')) {
    return SwapsNotRestorableFailure(message);
  }
  if (lower.contains('not yet final') || lower.contains('timelock')) {
    return SwapsRefundNotFinalFailure(message);
  }
  if (lower.contains('timed out') ||
      lower.contains('timeout') ||
      lower.contains('connection') ||
      lower.contains('refused') ||
      lower.contains('lookup') ||
      lower.contains('socket') ||
      lower.contains('electrum servers')) {
    return SwapsNetworkFailure(message);
  }
  return SwapsUnexpectedFailure(message);
}
