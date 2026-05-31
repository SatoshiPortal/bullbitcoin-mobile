import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';

/// The single Electrum fallback-loop implementation. Internal to the electrum
/// module — every consumer goes through [ElectrumServersPort.runWithFallback],
/// which is the only public entry point. Keeping the loop here (instead of
/// inlining it inside the adapter) is purely so it can be unit-tested in
/// isolation; nothing in `lib/` outside the electrum adapter should import it.
///
/// It is generic over the server type [S] so the adapter test can pin loop
/// semantics with a lightweight stand-in. [urlOf] and [isCustomOf] extract the
/// two fields the runner needs to build [ElectrumServerAttempt] entries.
///
/// IMPORTANT: this runner does NOT select servers. [servers] must already be
/// the resolved active set — custom-if-set else defaults, in priority order
/// (always produced by `fetchActiveServers`). The runner only iterates that
/// set, which is what guarantees a failing custom server is never silently
/// replaced by a default one. Throws [ArgumentError] on an empty list — the
/// adapter is expected to surface [NoElectrumServersConfiguredException]
/// beforehand, so reaching the runner with an empty set is a bug, not a state.
///
/// [isTransient] decides whether an error warrants trying the next server.
/// Transient → advance; permanent → rethrow immediately (another server cannot
/// fix an invalid operation). Defaults to `e is Exception`, so `Error`
/// subclasses (programming bugs: `TypeError`, `StateError`, failed asserts)
/// propagate immediately instead of being masked as "all servers failed".
Future<R> runElectrumFallback<S, R>({
  required List<S> servers,
  required String Function(S server) urlOf,
  required bool Function(S server) isCustomOf,
  required Future<R> Function(S server) operation,
  bool Function(Object error)? isTransient,
}) async {
  if (servers.isEmpty) {
    throw ArgumentError.value(
      servers,
      'servers',
      'runElectrumFallback requires a non-empty set; '
          'callers must surface NoElectrumServersConfiguredException first',
    );
  }

  final transient = isTransient ?? _defaultIsTransient;
  final attempts = <ElectrumServerAttempt>[];

  for (final server in servers) {
    try {
      return await operation(server);
    } catch (e) {
      if (!transient(e)) rethrow;
      attempts.add(
        ElectrumServerAttempt(
          url: urlOf(server),
          isCustom: isCustomOf(server),
          error: e,
        ),
      );
    }
  }

  throw AllElectrumServersFailedException(attempts);
}

bool _defaultIsTransient(Object e) => e is Exception;
