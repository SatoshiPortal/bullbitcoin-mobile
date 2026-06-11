import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

/// The single entry point for *using* Electrum servers.
///
/// Server selection lives behind this port exactly once:
/// - if the user configured custom server(s), only those are used;
/// - otherwise the default set is used;
/// - servers are tried in priority order, never mixing the two tiers.
///
/// The resolved server list is deliberately NOT exposed: callers cannot grab
/// it and re-implement (or skip) the selection/fallback rule. Every Electrum
/// interaction routes through [runWithFallback], which makes the rule —
/// including the privacy guarantee that a failing custom server is never
/// replaced by a default — impossible to bypass at this seam.
///
/// The adapter merges three sources to build each [ElectrumConnection]:
/// active servers (custom-if-set else defaults), persisted electrum settings
/// (retry / timeout / stopGap / validate), and the current Tor preference.
abstract class ElectrumServersPort {
  /// Runs [operation] against the active servers for [network] in priority
  /// order, falling back to the next server when one fails.
  ///
  /// - The active set is resolved once (custom-if-set else defaults) and the
  ///   loop only ever iterates that set, so a failing custom server is never
  ///   silently replaced by a default one.
  /// - [isTransient] decides whether an error warrants trying the next server.
  ///   A *transient* error (timeout, connection refused, protocol hiccup)
  ///   advances to the next server; a *permanent* error (the operation itself
  ///   is invalid) is rethrown immediately, since another server cannot help.
  ///   Defaults to `e is Exception` — programming bugs (`Error` subclasses)
  ///   propagate immediately instead of being masked as a server failure.
  ///
  /// Throws [NoElectrumServersConfiguredException] when no servers exist, or
  /// [AllElectrumServersFailedException] when every server failed transiently.
  Future<T> runWithFallback<T>({
    required ElectrumServerNetwork network,
    required Future<T> Function(ElectrumConnection connection) operation,
    bool Function(Object error)? isTransient,
  });
}
