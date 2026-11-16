import 'package:bull_tor/tor.dart';
import 'package:primitives/primitives.dart';

import 'recoverbull_failure.dart';

/// Selected by the settings owner, preserving external-proxy preference and
/// develop's circuit-isolated session lifetime. Never acquires in advance.
abstract interface class RecoverBullRoutePort {
  /// [viaSnowflake] restarts embedded Tor straight through Snowflake, when the
  /// user's mode lets the app choose its transport (see [snowflakeAvailable]).
  Future<Result<RecoverBullRoute, RecoverBullFailure>> open({
    bool restartEmbedded = false,
    bool viaSnowflake = false,
  });

  /// Whether the user's Tor settings let a flow restart through Snowflake.
  bool get snowflakeAvailable;

  /// Tor readiness for the connection screen: the current state, then changes.
  /// Observing never acquires a route.
  Stream<TorConnectionState> watch();
}

final class RecoverBullRoute {
  final TorRoute route;
  final Future<void> Function() _release;
  Future<void>? _closing;

  RecoverBullRoute(this.route, this._release);

  Future<void> close() => _closing ??= _release();
}
