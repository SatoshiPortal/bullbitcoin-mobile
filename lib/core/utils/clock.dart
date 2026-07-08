/// An injectable source of the current time.
///
/// Signing and ordering paths (the keychain-manifest Nostr event `created_at`,
/// the manifest file `generatedAt`, the entry timestamps, and the Bullpay
/// request timestamp) previously read `DateTime.now()` directly, which made the
/// clock impossible to control in a test and left a latent bug class around the
/// signature time-window and recency ordering when a device clock is skewed.
///
/// [Clock] is the seam: production wires [SystemClock]; a test can register a
/// fake to drive a skewed device clock. Default behaviour is unchanged —
/// [SystemClock.nowUtc] returns exactly what the previous inline call did.
abstract interface class Clock {
  /// The current wall-clock time, in UTC.
  DateTime nowUtc();
}

/// The production [Clock]: reads the real device clock in UTC.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// Convenience for the paths that sign a Unix-seconds timestamp.
extension ClockSeconds on Clock {
  /// The current time as whole seconds since the Unix epoch (UTC).
  int nowSecs() => nowUtc().millisecondsSinceEpoch ~/ 1000;
}
