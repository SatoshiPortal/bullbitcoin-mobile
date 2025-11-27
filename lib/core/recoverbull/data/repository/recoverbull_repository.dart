import 'dart:convert';

import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_local_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bb_mobile/core/tor/domain/ports/tor_config_port.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:hex/hex.dart';

class RecoverBullRepository {
  final RecoverBullRemoteDatasource remoteDatasource;
  final RecoverbullSettingsDatasource recoverbullSettingsDatasource;
  final TorConfigPort torConfigPort;

  RecoverBullRepository({
    required this.remoteDatasource,
    required this.recoverbullSettingsDatasource,
    required this.torConfigPort,
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
    final externalProxy = await torConfigPort.getExternalTorConfig();
    await remoteDatasource.store(
      HEX.decode(identifier),
      utf8.encode(password),
      HEX.decode(salt),
      HEX.decode(vaultKey),
      externalProxy: externalProxy,
    );
  }

  Future<String> fetchVaultKey(
    String identifier,
    String password,
    String salt,
  ) async {
    final externalProxy = await torConfigPort.getExternalTorConfig();
    final vaultKey = await remoteDatasource.fetch(
      HEX.decode(identifier),
      utf8.encode(password),
      HEX.decode(salt),
      externalProxy: externalProxy,
    );
    return HEX.encode(vaultKey);
  }

  Future<void> trashVaultKey(
    String identifier,
    String password,
    String salt,
  ) async {
    final externalProxy = await torConfigPort.getExternalTorConfig();
    await remoteDatasource.trash(
      HEX.decode(identifier),
      utf8.encode(password),
      HEX.decode(salt),
      externalProxy: externalProxy,
    );
  }

  Future<void> checkConnection() async {
    final externalProxy = await torConfigPort.getExternalTorConfig();
    await remoteDatasource.checkConnection(externalProxy: externalProxy);
  }

  Future<Uri> fetchUrl() async {
    return await recoverbullSettingsDatasource.fetch();
  }

  Future<void> storeUrl(Uri url) async {
    await recoverbullSettingsDatasource.store(url);
  }

  Future<void> allowPermission(bool isGranted) async {
    await recoverbullSettingsDatasource.allowPermission(isGranted);
  }

  Future<bool> fetchPermission() async {
    return await recoverbullSettingsDatasource.fetchPermission();
  }
}
