import 'dart:io';

import 'package:bb_mobile/core/tor/data/datasources/tor_datasource.dart';
import 'package:bb_mobile/core/tor/domain/repositories/tor_repository.dart';
import 'package:flutter/rendering.dart';
import 'package:recoverbull/recoverbull.dart';

class TorRepositoryImpl implements TorRepository {
  final TorDatasource _torDatasource;

  TorRepositoryImpl(this._torDatasource);

  @override
  Future<bool> get isTorReady async {
    try {
      return await _torDatasource.isReady;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<SOCKSSocket> createSocket() async {
    if (!(await isTorReady)) {
      throw Exception('Tor is not ready yet!');
    }

    return await SOCKSSocket.create(
      proxyHost: InternetAddress.loopbackIPv4.address,
      proxyPort: _torDatasource.port,
    );
  }

  @override
  Future<void> start() async {
    await _torDatasource.enable();
    debugPrint('Tor started at port: ${_torDatasource.port}');
  }

  @override
  Future<void> stop() async {
    await _torDatasource.disable();
    debugPrint('Tor stopped');
  }

  @override
  bool get isStarted => _torDatasource.isEnabled;
}
