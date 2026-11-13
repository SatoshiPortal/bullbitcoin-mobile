import 'package:bull_tor/tor.dart';
import 'package:primitives/primitives.dart';

import 'recoverbull_failure.dart';

/// Selected by the settings owner, preserving external-proxy preference and
/// develop's circuit-isolated session lifetime. Never acquires in advance.
abstract interface class RecoverBullRoutePort {
  Future<Result<RecoverBullRoute, RecoverBullFailure>> open({
    bool restartEmbedded = false,
  });
}

final class RecoverBullRoute {
  final TorRoute route;
  final Future<void> Function() _release;
  Future<void>? _closing;

  RecoverBullRoute(this.route, this._release);

  Future<void> close() => _closing ??= _release();
}
