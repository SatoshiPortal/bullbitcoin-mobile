import 'package:background_tasks/background_tasks.dart';
import 'package:notifications/notifications.dart';

import 'data/background_preferences_repository_impl.dart';
import 'domain/usecases/background_preferences_usecase.dart';

BackgroundPreferencesUsecase createBackgroundPreferences(
  BackgroundSchedule schedule, {
  required String notificationChannelId,
}) => BackgroundPreferencesUsecase(
  BackgroundPreferencesRepositoryImpl(
    schedule,
    NotificationPermissionsFacade(
      gateway: notificationPermissions(channelId: notificationChannelId),
    ),
  ),
);
