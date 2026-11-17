import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../domain/ports/network_presence_port.dart';

/// Tracks whether any network interface is up, through connectivity_plus.
///
/// Unknown until the first answer, and treated as absent meanwhile, so an
/// early "offline" verdict is never turned into a censorship claim.
final class ConnectivityNetworkPresence implements NetworkPresencePort {
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _changes;
  bool _hasNetwork = false;

  ConnectivityNetworkPresence({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    _changes = _connectivity.onConnectivityChanged.listen(
      _update,
      onError: (Object _) {},
    );
    unawaited(
      _connectivity.checkConnectivity().then(_update, onError: (Object _) {}),
    );
  }

  @override
  bool get hasNetwork => _hasNetwork;

  void _update(List<ConnectivityResult> results) {
    _hasNetwork = results.any((result) => result != ConnectivityResult.none);
  }

  Future<void> dispose() async => _changes?.cancel();
}
