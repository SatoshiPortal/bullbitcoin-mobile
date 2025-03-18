import 'package:bb_mobile/_core/domain/repositories/tor_repository.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:recoverbull/recoverbull.dart';

abstract class RecoverBullRemoteDatasource {
  Future<void> info();

  Future<void> store(
    List<int> backupId,
    List<int> password,
    List<int> salt,
    List<int> backupKey,
  );

  Future<List<int>> fetch(
    List<int> backupId,
    List<int> password,
    List<int> salt,
  );

  Future<void> trash(
    List<int> backupId,
    List<int> password,
    List<int> salt,
  );
}

class RecoverBullRemoteDatasourceImpl implements RecoverBullRemoteDatasource {
  final KeyServer _keyServer;
  final TorRepository _torRepository;

  RecoverBullRemoteDatasourceImpl._({
    required KeyServer keyServer,
    required TorRepository torRepository,
  })  : _keyServer = keyServer,
        _torRepository = torRepository;

  static Future<RecoverBullRemoteDatasource> init(Uri address) async {
    // Get the TorRepository from the locator
    final torRepository = locator<TorRepository>();

    // Make sure Tor is ready
    final isTorReady = await torRepository.isTorReady();
    if (!isTorReady) {
      // If Tor isn't ready, initialize it, or should we  use an completer to handle the tor initalization?
      throw Exception('Tor is not ready');
    }

    final keyServer = KeyServer(address: address);

    return RecoverBullRemoteDatasourceImpl._(
      keyServer: keyServer,
      torRepository: torRepository,
    );
  }

  @override
  Future<void> info() async {
    final socket = await _torRepository.createSocket();
    try {
      await _keyServer.infos(socks: socket);
    } on Exception catch (e) {
      debugPrint('serverinfo error: $e');
      rethrow;
    }
  }

  @override
  Future<void> store(
    List<int> backupId,
    List<int> password,
    List<int> salt,
    List<int> backupKey,
  ) async {
    final socket = await _torRepository.createSocket();
    try {
      await _keyServer.storeBackupKey(
        backupId: backupId,
        password: password,
        backupKey: backupKey,
        salt: salt,
        socks: socket,
      );
    } catch (e) {
      debugPrint('storeBackupKey error: $e');
      rethrow;
    }
  }

  @override
  Future<List<int>> fetch(
    List<int> backupId,
    List<int> password,
    List<int> salt,
  ) async {
    final socket = await _torRepository.createSocket();
    try {
      return await _keyServer.fetchBackupKey(
        backupId: backupId,
        password: password,
        salt: salt,
        socks: socket,
      );
    } catch (e) {
      debugPrint('fetchBackupKey error: $e');
      rethrow;
    }
  }

  @override
  Future<void> trash(
    List<int> backupId,
    List<int> password,
    List<int> salt,
  ) async {
    final socket = await _torRepository.createSocket();
    try {
      await _keyServer.trashBackupKey(
        backupId: backupId,
        password: password,
        salt: salt,
        socks: socket,
      );
    } catch (e) {
      debugPrint('trashBackupKey error: $e');
      rethrow;
    }
  }
}
