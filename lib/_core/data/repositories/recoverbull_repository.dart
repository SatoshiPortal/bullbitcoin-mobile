import 'dart:convert';
import 'package:bb_mobile/_core/data/datasources/recoverbull_local_datasource.dart';
import 'package:bb_mobile/_core/data/datasources/recoverbull_remote_datasource.dart';

import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/tor_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:hex/hex.dart';

class RecoverBullRepositoryImpl implements RecoverBullRepository {
  final RecoverBullLocalDatasource localDatasource;
  final RecoverBullRemoteDatasource remoteDatasource;
  final TorRepository torRepository;
  RecoverBullRepositoryImpl({
    required this.localDatasource,
    required this.remoteDatasource,
    required this.torRepository,
  });

  @override
  String createBackupFile(
    String backupKey,
    String plaintext,
  ) {
    final backupKeyBytes = HEX.decode(backupKey);
    final plaintextBytes = utf8.encode(plaintext);

    final jsonBackup =
        localDatasource.createBackup(plaintextBytes, backupKeyBytes);

    return jsonBackup;
  }

  @override
  String restoreBackupFile(
    String backupFile,
    String backupKey,
  ) {
    try {
      final decryptedBytes = localDatasource.restoreBackup(
        backupFile,
        HEX.decode(backupKey),
      );

      return utf8.decode(decryptedBytes);
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      rethrow;
    }
  }

  @override
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

  @override
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

  @override
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

  @override
  Future<void> checkKeyServerConnectionWithTor() async {
    final isTorReady = await torRepository.isTorReady();
    if (!isTorReady) {
      throw Exception('Tor is not ready');
    }
    final socket = await torRepository.createSocket();
    await remoteDatasource.info(socket);
  }
}
