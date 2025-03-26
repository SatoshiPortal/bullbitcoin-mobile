import 'dart:io';
import 'package:bb_mobile/_core/data/datasources/tor_datasource.dart';
import 'package:bb_mobile/_core/domain/repositories/tor_repository.dart';
import 'package:flutter/rendering.dart';
import 'package:recoverbull/recoverbull.dart';

class TorRepositoryImpl implements TorRepository {
  final TorDatasource _torDatasource;
  bool _initialized = false;

  TorRepositoryImpl(this._torDatasource);

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await start();
      _initialized = true;
    }
  }

  @override
  Future<bool> isTorReady() async {
    try {
      await _ensureInitialized();
      return _torDatasource.isReady;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<SOCKSSocket> createSocket() async {
    await _ensureInitialized();

    final isReady = await isTorReady();
    if (!isReady) {
      throw Exception('Tor is not ready');
    }

    return await SOCKSSocket.create(
      proxyHost: InternetAddress.loopbackIPv4.address,
      proxyPort: _torDatasource.port,
    );
  }

  @override
  Future<void> start() async {
    await _torDatasource.start();
    debugPrint('Tor started at port: ${_torDatasource.port}');
  }

  @override
  Future<void> stop() async {
    await _torDatasource.kill();
    debugPrint('Tor stopped');
  }
}
