import 'dart:io';

import 'package:bb_mobile/core/tor/data/datasources/tor_datasource.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:recoverbull/recoverbull.dart';

class TorRepository {
  final TorDatasource _torDatasource;

  TorRepository(this._torDatasource);

  Future<bool> get isTorReady async {
    try {
      return await _torDatasource.isReady;
    } catch (e) {
      return false;
    }
  }

  Future<SOCKSSocket> createSocket() async {
    if (!(await isTorReady)) throw Exception('Tor is not ready yet!');

    return await SOCKSSocket.create(
      proxyHost: InternetAddress.loopbackIPv4.address,
      proxyPort: _torDatasource.port,
    );
  }

  Future<void> start() async {
    await _torDatasource.enable();
    log.fine('Tor started at port: ${_torDatasource.port}');
  }

  void stop() {
    _torDatasource.disable();
    log.fine('Tor stopped');
  }

  bool get isStarted => _torDatasource.isEnabled;
}
