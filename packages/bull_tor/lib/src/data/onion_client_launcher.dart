import 'package:bull_sdk/onion.dart' as onion;

import '../domain/entities/tor_transport.dart';

/// Where the embedded Tor clients keep their files.
final class TorDirectories {
  /// Arti state (guards, bridge descriptors) of the direct client.
  final String directState;

  /// Arti state of the Snowflake client.
  final String snowflakeState;

  /// Arti's directory cache, shared by both clients.
  final String cache;

  const TorDirectories({
    required this.directState,
    required this.snowflakeState,
    required this.cache,
  });

  /// The state directory the client for [transport] owns.
  ///
  /// Arti only lets a client that holds the state-directory lock use bridges
  /// (`tor-guardmgr` refuses with `GuardMgrConfigError::NoLock`, surfaced as
  /// "Error setting up the guard manager"), and a stopped client releases
  /// that lock only once arti's background tasks drop it, which the onion API
  /// cannot await. Snowflake started right after an abandoned direct start
  /// therefore failed when both shared one directory. Each transport owning
  /// its own removes that contention.
  ///
  /// The cache needs no such split: arti's directory store opens read-only
  /// when another client holds its `dir.lock` (an `flock`, so it also works
  /// between two clients of one process), retries the lock every 5 s, and
  /// SQLite arbitrates the readers.
  String stateFor(TorTransport transport) => switch (transport) {
    TorTransport.direct => directState,
    TorTransport.snowflake => snowflakeState,
  };
}

/// What one embedded Tor client is started with.
final class OnionClientConfig {
  final TorTransport transport;
  final String stateDir;
  final String cacheDir;

  /// The loopback port of the Snowflake proxy, for a Snowflake client.
  final int? snowflakePort;

  const OnionClientConfig({
    required this.transport,
    required this.stateDir,
    required this.cacheDir,
    this.snowflakePort,
  });
}

/// The calls into `package:onion` that bring an embedded client up, kept
/// behind an interface so the configuration they receive can be checked
/// without native code.
abstract interface class OnionClientLauncher {
  Future<onion.TorService> startClient(
    OnionClientConfig config,
    onion.SocksPolicy policy,
  );

  /// Starts the process-wide Snowflake proxy and returns its loopback port.
  Future<int> startSnowflakeProxy();

  Future<void> stopSnowflakeProxy();
}

/// [OnionClientLauncher] backed by the native `package:onion` client.
final class NativeOnionClientLauncher implements OnionClientLauncher {
  const NativeOnionClientLauncher();

  @override
  Future<onion.TorService> startClient(
    OnionClientConfig config,
    onion.SocksPolicy policy,
  ) => switch (config.transport) {
    TorTransport.direct => onion.TorService.start(
      stateDir: config.stateDir,
      cacheDir: config.cacheDir,
      socksPort: 0,
      policy: policy,
    ),
    TorTransport.snowflake => onion.TorService.startWithSnowflake(
      stateDir: config.stateDir,
      cacheDir: config.cacheDir,
      socksPort: 0,
      snowflakePort: config.snowflakePort!,
      policy: policy,
    ),
  };

  @override
  Future<int> startSnowflakeProxy() => onion.SnowflakeTransport.start();

  @override
  Future<void> stopSnowflakeProxy() => onion.SnowflakeTransport.stop();
}
