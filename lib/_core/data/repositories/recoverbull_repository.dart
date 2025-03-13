import 'dart:convert';
import 'package:bb_mobile/_core/data/datasources/bip85_datasource.dart';
import 'package:bb_mobile/_core/data/datasources/recoverbull_local_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/recoverbull_remote_data_source.dart';
import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:hex/hex.dart';

class RecoverBullRepositoryImpl implements RecoverBullRepository {
  final RecoverBullLocalDataSource localDataSource;
  final RecoverBullRemoteDataSource remoteDataSource;
  final Bip85DataSource bip85dataSource;

  RecoverBullRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.bip85dataSource,
  });

  @override
  Future<String> createBackupFile(String xprv) async {
    const plaintext = <int>[]; // wallets

    // derive a backup key from a random bip85 path
    final derivationPath = bip85dataSource.generateBackupKeyPath();
    final backupKey =
        bip85dataSource.derive(xprv, derivationPath).sublist(0, 32);

    final jsonBackup = localDataSource.createBackup(plaintext, backupKey);

    // append the path to the backup file
    final mapBackup = json.decode(jsonBackup);
    mapBackup['path'] = derivationPath;

    return json.encode(mapBackup);
  }

  @override
  void restoreBackupFile(String backupFile, String backupKey) {
    final secret =
        localDataSource.restoreBackup(backupFile, HEX.decode(backupKey));
    // TODO: overwrite wallets etc…
  }

  @override
  Future<void> storeBackupKey(
    String identifier,
    String password,
    String salt,
    String backupKey,
  ) async {
    await remoteDataSource.store(
      HEX.decode(identifier),
      utf8.encode(password),
      HEX.decode(salt),
      HEX.decode(backupKey),
    );
  }

  @override
  Future<String> fetchBackupKey(
    String identifier,
    String password,
    String salt,
  ) async {
    final backupKey = await remoteDataSource.fetch(
      HEX.decode(identifier),
      utf8.encode(password),
      HEX.decode(salt),
    );
    return HEX.encode(backupKey);
  }

  @override
  Future<void> trashBackupKey(
    String identifier,
    String password,
    String salt,
  ) async {
    await remoteDataSource.trash(
      HEX.decode(identifier),
      utf8.encode(password),
      HEX.decode(salt),
    );
  }
}
