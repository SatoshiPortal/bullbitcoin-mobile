import 'package:bull_tor/tor.dart';
import 'package:primitives/primitives.dart';

import '../domain/recoverbull_failure.dart';
import '../domain/recoverbull_route_port.dart';
import '../domain/recoverbull_server_url.dart';
import '../domain/repositories/key_server_repository.dart';
import '../domain/repositories/key_server_session_repository.dart';
import 'key_server_repository_impl.dart';

final class KeyServerSessionRepositoryImpl
    implements KeyServerSessionRepository {
  final RecoverBullRoutePort _routes;
  final TorHttpClientFactory _clients;

  const KeyServerSessionRepositoryImpl(this._routes, this._clients);

  @override
  Future<Result<KeyServerRepository, RecoverBullFailure>> open(
    Uri server, {
    bool restartEmbedded = false,
  }) async {
    if (!isValidRecoverBullServerUrl(server)) {
      return const Err(VaultInvalidFailure());
    }
    final result = await _routes.open(restartEmbedded: restartEmbedded);
    switch (result) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        try {
          KeyServerFailureKind? connectFailure;
          final client = _clients.create(
            value.route.endpoint,
            onConnectFailure: (failure) {
              connectFailure = failure == TorConnectFailure.timeout
                  ? KeyServerFailureKind.timeout
                  : KeyServerFailureKind.unavailable;
            },
          );
          return Ok(
            KeyServerRepositoryImpl(
              server: server,
              transport: client,
              releaseRoute: value.close,
              takeConnectFailure: () {
                final failure = connectFailure;
                connectFailure = null;
                return failure;
              },
            ),
          );
        } on Exception {
          await value.close();
          return const Err(KeyServerFailure(KeyServerFailureKind.unavailable));
        }
    }
  }
}
