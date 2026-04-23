import 'package:bb_mobile/features/app_startup/app_startup_locator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

final GetIt locator = GetIt.instance;

class AppLocator {
  static Future<void> setup() async {
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(
        resetOnError: false,
        recoveryMode: true,
        migrateWithBackup: false,
        migrateOnAlgorithmChange: false,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
    locator.registerLazySingleton<FlutterSecureStorage>(() => secureStorage);

    AppStartupLocator.setup(locator);
  }
}
