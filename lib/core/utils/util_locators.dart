import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/locator.dart';

class UtilsLocator {
  static Future<void> registerLogger() async {
    final logger = await Logger.create(null);
    locator.registerLazySingleton<Logger>(() => logger);
  }
}
