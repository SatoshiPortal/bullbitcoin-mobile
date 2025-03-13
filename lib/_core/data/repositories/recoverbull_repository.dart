import 'dart:convert';
import 'package:bb_mobile/_core/data/datasources/recoverbull_local_data_source.dart';
import 'package:bb_mobile/_core/data/datasources/recoverbull_remote_data_source.dart';
import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/_utils/bip85_derivation.dart';
import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart';

class RecoverBullRepositoryImpl implements RecoverBullRepository {
  final RecoverBullLocalDataSource localDataSource;
  final RecoverBullRemoteDataSource remoteDataSource;

  RecoverBullRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<String> createBackupFile(String xprv) async {
    const plaintext = <int>[]; // wallets

    // derive a backup key from a random bip85 path
    final derivationPath = Bip85Derivation.generateBackupKeyPath();
    final backupKey =
        Bip85Derivation.derive(xprv, derivationPath).sublist(0, 32);

    final jsonBackup = localDataSource.createBackup(plaintext, backupKey);

    // append the path to the backup file
    final mapBackup = json.decode(jsonBackup);
    mapBackup['path'] = derivationPath;

    return json.encode(mapBackup);
  }

  @override
  void restoreBackupFile(String backupFile, String backupKey) {
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
    SOCKSSocket?
        socks; // TODO: should be replaced by a Tor repository to get the Socks

    await remoteDataSource.store(
      socks,
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
    SOCKSSocket?
        socks; // TODO: should be replaced by a Tor repository to get the Socks

    final backupKey = await remoteDataSource.fetch(
      socks,
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
    SOCKSSocket?
        socks; // TODO: should be replaced by a Tor repository to get the Socks

    await remoteDataSource.trash(
      socks,
      HEX.decode(identifier),
      utf8.encode(password),
      HEX.decode(salt),
    );
  }
}
