import 'dart:io';

import 'package:bb_mobile/core/tor/domain/value_objects/tor_proxy_config.dart';
import 'package:bb_mobile/core/tor/errors.dart';
import 'package:bb_mobile/core/tor/tor_status.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:socks5_proxy/socks_client.dart';
import 'package:tor/tor.dart';

class TorDatasource {
  final Tor _tor;
  TorStatus status = TorStatus.unknown;

  TorDatasource._(this._tor);

  static Future<TorDatasource> init() async {
    final tor = await Tor.init(enabled: false);
    return TorDatasource._(tor);
  }

  int? get port => _tor.port;

  Future<void> start() async {
    if (isStarted ||
        status == TorStatus.connecting ||
        status == TorStatus.online) {
      return;
    }

    log.config('Starting Tor...');
    status = TorStatus.connecting;
    final start = DateTime.now();
    await _tor.enable();
    log.config('Tor enabled');
    await _tor.start();
    log.config('Tor started');
    await _tor.isReady();
    log.config('Tor ready');
    final end = DateTime.now();
    log.fine(
      'Tor started in ${end.difference(start).inSeconds}s on port ${_tor.port}',
    );
    status = TorStatus.online;
  }

  bool get isStarted {
    try {
      return _tor.enabled && _tor.bootstrapped && _tor.port != -1;
    } catch (e) {
      return false;
    }
  }

  HttpClient httpClient({TorProxyConfig? externalProxy}) {
    final int proxyPort;

    if (externalProxy != null) {
      proxyPort = externalProxy.port;
    } else {
      if (!isStarted) throw TorNotStartedError();
      proxyPort = _tor.port;
    }

    final client = HttpClient();
    SocksTCPClient.assignToHttpClient(client, [
      ProxySettings(InternetAddress.loopbackIPv4, proxyPort, password: null),
    ]);

    return client;
  }

  void disable() => _tor.disable();

  Future<void> kill() async {
    disable();
    await _tor.stop();
    status = TorStatus.offline;
  }
}
