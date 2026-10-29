import 'dart:async';

import 'package:nm/nm.dart';

typedef LinuxCbfNetworkSignal = ({bool available, bool? metered});

/// Reads cached NetworkManager properties and observes D-Bus property changes.
/// No CheckConnectivity call, DNS request, socket probe or configuration write.
final class LinuxCbfNetworkSignals {
  final NetworkManagerClient Function() _createClient;
  final _changes = StreamController<LinuxCbfNetworkSignal>.broadcast(
    sync: true,
  );
  NetworkManagerClient? _client;
  Future<NetworkManagerClient?>? _connecting;
  StreamSubscription<List<String>>? _properties;
  bool _disposed = false;

  LinuxCbfNetworkSignals({NetworkManagerClient Function()? createClient})
    : _createClient = createClient ?? NetworkManagerClient.new;

  Stream<LinuxCbfNetworkSignal> get changes => _changes.stream;

  Future<LinuxCbfNetworkSignal?> read() async {
    if (_disposed) return null;
    final client = await (_connecting ??= _connect());
    if (_disposed || client == null) return null;
    return _snapshot(client);
  }

  Future<NetworkManagerClient?> _connect() async {
    final client = _createClient();
    try {
      await client.connect().timeout(const Duration(seconds: 2));
      if (_disposed || client.version.isEmpty) {
        await client.close();
        _connecting = null;
        return null;
      }
      _client = client;
      _properties = client.propertiesChanged.listen(
        (names) {
          if (_disposed) return;
          const relevant = {
            'Metered',
            'State',
            'Connectivity',
            'PrimaryConnection',
            'PrimaryConnectionType',
            'NetworkingEnabled',
          };
          if (names.any(relevant.contains)) {
            _changes.add(_snapshot(client));
          }
        },
        onError: (Object _) {
          // An observation failure is unknown, not proof that a peer is lost.
        },
      );
      return client;
    } on Exception {
      try {
        await client.close();
      } on Exception {
        // Preserve the original unavailable observation.
      }
      _connecting = null;
      return null;
    }
  }

  static LinuxCbfNetworkSignal _snapshot(NetworkManagerClient client) =>
      mapLinuxCbfNetworkSignal(
        state: client.state,
        connectivity: client.connectivity,
        metered: client.metered,
      );

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _properties?.cancel();
    final client = _client;
    if (client != null) {
      await client.close();
    } else {
      // _connect closes a candidate completed after disposal.
      await _connecting;
    }
    await _changes.close();
  }
}

/// The system may disable its own connectivity check; do not require `full`
/// when NetworkManager already reports a globally connected default route.
LinuxCbfNetworkSignal mapLinuxCbfNetworkSignal({
  required NetworkManagerState state,
  required NetworkManagerConnectivityState connectivity,
  required NetworkManagerMetered metered,
}) => (
  available:
      connectivity != NetworkManagerConnectivityState.none &&
      connectivity != NetworkManagerConnectivityState.portal &&
      (state == NetworkManagerState.connectedGlobal ||
          connectivity == NetworkManagerConnectivityState.full),
  metered: switch (metered) {
    NetworkManagerMetered.yes || NetworkManagerMetered.guessYes => true,
    NetworkManagerMetered.no || NetworkManagerMetered.guessNo => false,
    NetworkManagerMetered.unknown => null,
  },
);
