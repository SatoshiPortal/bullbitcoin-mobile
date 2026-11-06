import 'package:background_tasks/background_tasks.dart';
import 'package:notifications/notifications.dart';
import 'package:get_it/get_it.dart';
import 'data/background_preferences_repository_impl.dart';
import 'domain/usecases/background_preferences_usecase.dart';
import 'presentation/bloc/background_preferences_cubit.dart';

void setupBackgroundPreferences(
  GetIt locator,
  Future<void> Function() configureBackgroundTasks, {
  required String notificationChannelId,
}) {
  final backgroundPreferences = BackgroundPreferencesUsecase(
    BackgroundPreferencesRepositoryImpl(
      const SharedPreferencesBackgroundSyncIntervalStore(),
      NotificationPermissionsFacade(
        gateway: FlutterNotificationPermissionGateway(
          channelId: notificationChannelId,
        ),
      ),
      configureBackgroundTasks,
    ),
  );
  locator.registerFactory<BackgroundPreferencesCubit>(
    () => BackgroundPreferencesCubit(backgroundPreferences),
  );
}
