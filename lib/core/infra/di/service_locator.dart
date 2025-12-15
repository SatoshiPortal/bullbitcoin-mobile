import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> registerCoreDependencies() async {
  _registerCoreInfra();
}

void _registerCoreInfra() {
  // Register a single instance of FlutterSecureStorage to be used across the app
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  );
  // Register SqliteDatabase instance
  sl.registerLazySingleton<SqliteDatabase>(() => SqliteDatabase());
}
