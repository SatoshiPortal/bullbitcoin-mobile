import 'package:bb_mobile/core/notifications/notifications_service.dart';
import 'package:get_it/get_it.dart';

class NotificationsLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<NotificationsService>(
      () => NotificationsService(),
    );
  }
}
