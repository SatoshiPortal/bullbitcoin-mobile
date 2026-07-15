import 'package:bb_mobile/core/tor/data/datasources/tor_datasource.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';

/// Resolves the SOCKS5 proxy every joinstr connection is routed through.
///
/// joinstr is Tor-only: the relay and the electrum server would otherwise see
/// the joining IP next to the coin being mixed, which defeats the coinjoin.
/// The bindings open a fresh circuit per connection, so this only needs to
/// hand them the local Tor SOCKS address.
class ResolveJoinstrProxyUsecase {
  final TorDatasource _torDatasource;

  ResolveJoinstrProxyUsecase({required this._torDatasource});

  Future<String> execute() async {
    // Idempotent: returns immediately if Tor is already online. joinstr forces
    // Tor on regardless of the app's global Tor setting.
    await _torDatasource.start();
    final port = _torDatasource.port;
    if (!_torDatasource.isStarted || port == null || port <= 0) {
      throw JoinstrException(JoinstrIssue.torUnavailable);
    }
    return '127.0.0.1:$port';
  }
}
