import 'dart:io';

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
    await _tor.start();
    await _tor.isReady();
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

  HttpClient get httpClient {
    if (!isStarted) throw TorNotStartedError();

    final client = HttpClient();
    SocksTCPClient.assignToHttpClient(client, [
      ProxySettings(InternetAddress.loopbackIPv4, _tor.port, password: null),
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
