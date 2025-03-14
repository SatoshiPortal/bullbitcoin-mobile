import 'package:bb_mobile/_core/data/datasources/bip85_datasource.dart';
import 'package:bb_mobile/_core/domain/repositories/bip85_repository.dart';

class Bip85RepositoryImpl implements Bip85Repository {
  final Bip85DataSource dataSource;

  Bip85RepositoryImpl(this.dataSource);

  @override
  List<int> derive(String xprv, String path) {
    return dataSource.derive(xprv, path);
  }

  @override
  String generateBackupKeyPath() {
    return dataSource.generateBackupKeyPath();
  }
}
