import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_local_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/tor/domain/repositories/tor_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:hex/hex.dart';

class RecoverBullRepository {
  final RecoverBullRemoteDatasource remoteDatasource;
  final TorRepository torRepository;

  RecoverBullRepository({
    required this.remoteDatasource,
    required this.torRepository,
  });

  String createBackupFile(String backupKey, String plaintext) {
    final backupKeyBytes = HEX.decode(backupKey);
    final plaintextBytes = utf8.encode(plaintext);

    final jsonBackup = RecoverBullDatasource.create(
      plaintextBytes,
      backupKeyBytes,
    );

    return jsonBackup;
  }

  String restoreBackupFile(String backupFile, String backupKey) {
    try {
      final decryptedBytes = RecoverBullDatasource.restore(
        backupFile,
        HEX.decode(backupKey),
      );

      return utf8.decode(decryptedBytes);
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      rethrow;
    }
  }

  Future<void> storeBackupKey(
    String identifier,
    String password,
    String salt,
    String backupKey,
  ) async {
    final socket = await torRepository.createSocket();

    await remoteDatasource.store(
      HEX.decode(identifier),
      utf8.encode(password),
      HEX.decode(salt),
      HEX.decode(backupKey),
      socket,
    );
  }

  Future<String> fetchBackupKey(
    String identifier,
    String password,
    String salt,
  ) async {
    final socket = await torRepository.createSocket();
    final backupKey = await remoteDatasource.fetch(
      HEX.decode(identifier),
      utf8.encode(password),
      HEX.decode(salt),
      socket,
    );
    return HEX.encode(backupKey);
  }

  Future<void> trashBackupKey(
    String identifier,
    String password,
    String salt,
  ) async {
    final socket = await torRepository.createSocket();
    await remoteDatasource.trash(
      HEX.decode(identifier),
      utf8.encode(password),
      HEX.decode(salt),
      socket,
    );
  }

  Future<void> checkKeyServerConnectionWithTor() async {
    if (!torRepository.isStarted) {
      debugPrint('Starting Tor');
      await torRepository.start();
    }
    final isTorReady = await torRepository.isTorReady;
    debugPrint('isTorReady: $isTorReady');
    if (!isTorReady) {
      throw Exception('Tor is not ready');
    }
    final socket = await torRepository.createSocket();
    await remoteDatasource.info(socket);
  }
}
