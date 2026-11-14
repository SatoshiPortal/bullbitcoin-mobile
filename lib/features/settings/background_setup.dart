import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/features/settings/data/background_preferences_repository_impl.dart';
import 'package:bb_mobile/features/settings/domain/usecases/background_preferences_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/background_preferences_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:notifications/notifications.dart';

void setupBackgroundPreferences(
  GetIt locator,
  Future<void> Function() configureBackgroundTasks, {
  required String notificationChannelId,
}) {
  final backgroundPreferences = BackgroundPreferencesUsecase(
    BackgroundPreferencesRepositoryImpl(
      const SharedPreferencesBackgroundSyncIntervalStore(),
      NotificationPermissionsFacade(
        gateway: notificationPermissions(channelId: notificationChannelId),
      ),
      configureBackgroundTasks,
    ),
  );
  locator.registerFactory<BackgroundPreferencesCubit>(
    () => BackgroundPreferencesCubit(backgroundPreferences),
  );
}
