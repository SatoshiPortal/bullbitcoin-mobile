import 'package:bb_mobile/core/utils/logger.dart';
import 'package:recoverbull/recoverbull.dart';

class RecoverBullRemoteDatasource {
  final KeyServer _keyServer;

  RecoverBullRemoteDatasource({required Uri address})
    : _keyServer = KeyServer(address: address);

  Future<void> info(SOCKSSocket socket) async {
    try {
      final info = await _keyServer.infos(socks: socket);
      log.info('KeyServer canary: ${info.canary}');
    } catch (e) {
      log.severe('infos error: $e');
      rethrow;
    }
  }

  Future<void> store(
    List<int> backupId,
    List<int> password,
    List<int> salt,
    List<int> backupKey,
    SOCKSSocket socket,
  ) async {
    try {
      await _keyServer.storeBackupKey(
        backupId: backupId,
        password: password,
        backupKey: backupKey,
        salt: salt,
        socks: socket,
      );
    } catch (e) {
      log.severe('storeBackupKey error: $e');
      rethrow;
    }
  }

  Future<List<int>> fetch(
    List<int> backupId,
    List<int> password,
    List<int> salt,
    SOCKSSocket socket,
  ) async {
    try {
      return await _keyServer.fetchBackupKey(
        backupId: backupId,
        password: password,
        salt: salt,
        socks: socket,
      );
    } catch (e) {
      log.severe('fetchBackupKey error: $e');
      rethrow;
    }
  }

  Future<void> trash(
    List<int> backupId,
    List<int> password,
    List<int> salt,
    SOCKSSocket socket,
  ) async {
    try {
      await _keyServer.trashBackupKey(
        backupId: backupId,
        password: password,
        salt: salt,
        socks: socket,
      );
    } catch (e) {
      log.severe('trashBackupKey error: $e');
      rethrow;
    }
  }
}
