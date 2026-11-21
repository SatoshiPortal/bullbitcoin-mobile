import 'tor_preferences.dart';

import 'dart:io';

import 'package:bull_tor/tor.dart';

/// Verifies an external SOCKS proxy before making it the configured route.
class UpdateTorProxyUsecase {
  final SaveTorProxy _saveProxy;
  final ExternalTor _externalTor;
  Future<void> _persistenceQueue = Future<void>.value();

  UpdateTorProxyUsecase(this._saveProxy, this._externalTor);

  Future<TorConnectionState> execute({
    required bool useTorProxy,
    required int torProxyPort,
    bool Function()? isCurrent,
  }) async {
    if (!useTorProxy) {
      final stored = await _persist(
        () => _saveProxy(enabled: false, port: torProxyPort),
        isCurrent,
      );
      if (!stored) {
        return const TorUnavailable(
          source: TorSource.external,
          failure: TorStorageFailure(),
        );
      }
      return const TorStopped(TorSource.external);
    }

    final TorProxyEndpoint endpoint;
    try {
      endpoint = TorProxyEndpoint(
        host: InternetAddress.loopbackIPv4.address,
        port: torProxyPort,
      );
    } on ArgumentError catch (error) {
      return TorUnavailable(
        source: TorSource.external,
        failure: TorExternalProxyUnavailableFailure(error.toString()),
      );
    }

    final connection = await _externalTor.verify(endpoint);
    if (connection is! TorReady) return connection;

    final stored = await _persist(
      () => _saveProxy(enabled: true, port: torProxyPort),
      isCurrent,
    );
    if (!stored) {
      return const TorUnavailable(
        source: TorSource.external,
        failure: TorStorageFailure(),
      );
    }

    return connection;
  }

  /// Runs [operation] on the serialized queue. Returns `false` only when a
  /// write actually failed, so callers decide rather than catching.
  ///
  /// A stale request is skipped and reported as `true`: nothing was written,
  /// but nothing went wrong either, and treating it as a failure would tell
  /// the user their Tor setting could not be saved when it was simply
  /// superseded.
  Future<bool> _persist(
    Future<bool> Function() operation,
    bool Function()? isCurrent,
  ) {
    final queued = _persistenceQueue.then((_) async {
      if (isCurrent != null && !isCurrent()) return true;
      return operation();
    });
    _persistenceQueue = queued.catchError((_) => false);
    return queued;
  }
}
