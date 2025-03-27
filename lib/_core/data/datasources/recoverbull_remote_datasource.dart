import 'package:flutter/foundation.dart' show debugPrint;
import 'package:recoverbull/recoverbull.dart';

abstract class RecoverBullRemoteDatasource {
  Future<void> info(SOCKSSocket socket);

  Future<void> store(
    List<int> backupId,
    List<int> password,
    List<int> salt,
    List<int> backupKey,
    SOCKSSocket socket,
  );

  Future<List<int>> fetch(
    List<int> backupId,
    List<int> password,
    List<int> salt,
    SOCKSSocket socket,
  );

  Future<void> trash(
    List<int> backupId,
    List<int> password,
    List<int> salt,
    SOCKSSocket socket,
  );
}

class RecoverBullRemoteDatasourceImpl implements RecoverBullRemoteDatasource {
  final KeyServer _keyServer;

  RecoverBullRemoteDatasourceImpl._({
    required KeyServer keyServer,
  }) : _keyServer = keyServer;

  static RecoverBullRemoteDatasource init(Uri address) {
    final keyServer = KeyServer(address: address);
    return RecoverBullRemoteDatasourceImpl._(
      keyServer: keyServer,
    );
  }

  @override
  Future<void> info(SOCKSSocket socket) async {
    try {
      final info = await _keyServer.infos(socks: socket);
      debugPrint('KeyServer connection success: ${info.canary}');
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
      debugPrint('storeBackupKey error: $e');
      rethrow;
    }
  }

  @override
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
      debugPrint('fetchBackupKey error: $e');
      rethrow;
    }
  }

  @override
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
      debugPrint('trashBackupKey error: $e');
      rethrow;
    }
  }
}
