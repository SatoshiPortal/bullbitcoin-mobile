import 'package:bb_mobile/core/tor/data/datasources/tor_datasource.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';

/// Resolves the SOCKS5 proxy every joinstr connection is routed through.
///
/// joinstr is Tor-only: the relay and the electrum server would otherwise see
/// the joining IP next to the coin being mixed, which defeats the coinjoin.
/// This uses the app's embedded Tor (the same one recoverbull uses), so no
/// external proxy such as Orbot is needed; the bindings open a fresh circuit
/// per connection.
class ResolveJoinstrProxyUsecase {
  final TorDatasource _torDatasource;

  /// Embedded Tor bootstrap can take a while on mobile (fetching the consensus
  /// on first run). Wait up to this long for it to come online.
  final Duration _timeout;
  final Duration _pollInterval;

  ResolveJoinstrProxyUsecase({
    required this._torDatasource,
    this._timeout = const Duration(minutes: 2),
    this._pollInterval = const Duration(seconds: 1),
  });

  Future<String> execute() async {
    // Kick off Tor if nothing else has. `start()` is a no-op while a start is
    // already in progress, so we then wait for bootstrap ourselves rather than
    // trusting its early return: another caller (e.g. the pool list on screen
    // open) may still be bootstrapping, and checking readiness immediately
    // would wrongly report Tor as unavailable.
    if (!_torDatasource.isStarted) {
      try {
        await _torDatasource.start();
      } catch (_) {
        // Swallow and fall through to the readiness poll: the failure may be a
        // concurrent start still in flight, which the poll will pick up.
      }
    }

    final deadline = DateTime.now().add(_timeout);
    while (!_torDatasource.isStarted) {
      if (DateTime.now().isAfter(deadline)) {
        throw JoinstrException(JoinstrIssue.torUnavailable);
      }
      await Future<void>.delayed(_pollInterval);
    }

    final port = _torDatasource.port ?? 0;
    if (port <= 0) throw JoinstrException(JoinstrIssue.torUnavailable);
    return '127.0.0.1:$port';
  }
}
