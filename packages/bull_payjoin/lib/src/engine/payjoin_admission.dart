import 'dart:async';

/// Carries "is the generation I began in still live?" from the wrapper that
/// admitted a call down to the engine that is about to sign or publish.
///
/// The check travels in the zone, so it follows the call across every await
/// without changing a role's signature. Code that is not run under an
/// admission (the engine's own background work) is always admitted.
const payjoinAdmissionKey = #bullPayjoinAdmission;

/// Whether the call this code runs for may still reach its first signature or
/// publication. Ask immediately before the first such effect, and not again
/// after it: past that frontier the caller gets the engine's real result.
bool payjoinAdmitted() {
  final check = Zone.current[payjoinAdmissionKey];
  return check is bool Function() ? check() : true;
}

/// Runs [body] under [admitted].
Future<T> runUnderPayjoinAdmission<T>(
  bool Function() admitted,
  Future<T> Function() body,
) => Zone.current.fork(zoneValues: {payjoinAdmissionKey: admitted}).run(body);
