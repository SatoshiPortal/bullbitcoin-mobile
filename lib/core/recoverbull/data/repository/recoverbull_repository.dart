import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_local_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/tor/data/repository/tor_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:hex/hex.dart';

class RecoverBullRepository {
  final RecoverBullRemoteDatasource remoteDatasource;
  final TorRepository torRepository;

  RecoverBullRepository({
    required this.remoteDatasource,
    required this.torRepository,
  });

  String createJsonVault(String vaultKey, String plaintext) {
    final backupKeyBytes = HEX.decode(vaultKey);
    final plaintextBytes = utf8.encode(plaintext);

    final jsonBackup = RecoverBullDatasource.create(
      plaintextBytes,
      backupKeyBytes,
    );

    return jsonBackup;
  }

  String restoreJsonVault(String vaultFile, String vaultKey) {
    try {
      final decryptedBytes = RecoverBullDatasource.restore(
        vaultFile,
        HEX.decode(vaultKey),
      );

      return utf8.decode(decryptedBytes);
    } catch (e) {
      log.severe('Error restoring backup: $e');
      rethrow;
    }
  }

  Future<void> storeVaultKey(
    String identifier,
    String password,
    String salt,
    String vaultKey,
  ) async {
    final socket = await torRepository.createSocket();

    await remoteDatasource.store(
      HEX.decode(identifier),
      utf8.encode(password),
      HEX.decode(salt),
      HEX.decode(vaultKey),
      socket,
    );
  }

  Future<String> fetchVaultKey(
    String identifier,
    String password,
    String salt,
  ) async {
    final socket = await torRepository.createSocket();
    final vaultKey = await remoteDatasource.fetch(
      HEX.decode(identifier),
      utf8.encode(password),
      HEX.decode(salt),
      socket,
    );
    return HEX.encode(vaultKey);
  }

  Future<void> trashVaultKey(
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
      log.config('Starting Tor');
      await torRepository.start();
    }

    final isTorReady = await torRepository.isTorReady;
    if (!isTorReady) throw Exception('Tor is not ready');
    log.config('Tor is ready');

    final socket = await torRepository.createSocket();
    await remoteDatasource.info(socket);
  }
}
