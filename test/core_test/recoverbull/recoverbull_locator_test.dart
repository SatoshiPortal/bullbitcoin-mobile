import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/recoverbull_locator.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:bull_tor/tor.dart';

void main() {
  test('registers synchronous RecoverBull dependencies without waiting', () {
    final locator = GetIt.asNewInstance()
      ..registerLazySingleton<SqliteDatabase>(SqliteDatabase.new)
      ..registerLazySingleton<TorHttpClientFactory>(TorHttpClientFactory.new);

    RecoverbullLocator.registerDatasources(locator);
    RecoverbullLocator.registerRepositories(locator);

    expect(locator.isRegistered<RecoverBullRemoteDatasource>(), isTrue);
    expect(locator.isRegistered<RecoverBullRepository>(), isTrue);
  });
}
