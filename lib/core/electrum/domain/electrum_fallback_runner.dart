import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';

/// The single Electrum fallback-loop implementation, shared by every consumer
/// (broadcast, sync, tx-fetch, payjoin) so the loop semantics live in one place.
///
/// It is generic over the server type [S] because different modules carry
/// different server value objects (the electrum-domain entity vs the richer
/// connection-config used by BDK/LWK). [urlOf] and [isCustomOf] extract the
/// two fields the runner needs for error reporting.
///
/// IMPORTANT: this runner does NOT select servers. [servers] must already be
/// the resolved active set — custom-if-set else defaults, in priority order
/// (always produced by `fetchActiveServers`). The runner only iterates that
/// set, which is what guarantees a failing custom server is never silently
/// replaced by a default one. Callers must pass a non-empty list (guard the
/// empty case with [NoElectrumServersConfiguredException] beforehand).
///
/// [isTransient] decides whether an error warrants trying the next server.
/// Transient → advance; permanent → rethrow immediately (another server cannot
/// fix an invalid operation). Defaults to treating every error as transient,
/// which preserves the historical "fall back on anything" behaviour.
Future<R> runElectrumFallback<S, R>({
  required List<S> servers,
  required String Function(S server) urlOf,
  required bool Function(S server) isCustomOf,
  required Future<R> Function(S server) operation,
  bool Function(Object error)? isTransient,
}) async {
  assert(servers.isNotEmpty, 'runElectrumFallback requires a non-empty set');

  final transient = isTransient ?? _everythingIsTransient;
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

bool _everythingIsTransient(Object _) => true;
