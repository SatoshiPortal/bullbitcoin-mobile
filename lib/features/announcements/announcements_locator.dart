import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/announcements/data/announcement_dismissal_repository_impl.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/dismiss_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/get_visible_announcements_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/watch_app_update_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/repositories/announcement_dismissal_repository.dart';
import 'package:bb_mobile/features/announcements/presentation/announcements_cubit.dart';
import 'package:get_it/get_it.dart';

class AnnouncementsLocator {
  static void setup(
    GetIt locator, {
    required bool Function() isAppUpdateRequired,
    required Stream<bool> Function() watchAppUpdateRequired,
  }) {
    // Data
    locator.registerLazySingleton<AnnouncementDismissalRepository>(
      () => AnnouncementDismissalRepositoryImpl(
        dismissals: locator<AnnouncementDismissals>(),
      ),
    );

    // Use-cases
    locator.registerFactory<GetVisibleAnnouncementsUsecase>(
      () => GetVisibleAnnouncementsUsecase(
        locator<AnnouncementDismissalRepository>(),
        isAppUpdateRequired,
      ),
    );
    locator.registerFactory<WatchAppUpdateAnnouncementUsecase>(
      () => WatchAppUpdateAnnouncementUsecase(watchAppUpdateRequired),
    );
    locator.registerFactory<DismissAnnouncementUsecase>(
      () => DismissAnnouncementUsecase(
        dismissalRepository: locator<AnnouncementDismissalRepository>(),
      ),
    );

    // Presentation
    locator.registerFactory<AnnouncementsCubit>(
      () => AnnouncementsCubit(
        getVisibleAnnouncementsUsecase:
            locator<GetVisibleAnnouncementsUsecase>(),
        dismissAnnouncementUsecase: locator<DismissAnnouncementUsecase>(),
        watchAppUpdateAnnouncementUsecase:
            locator<WatchAppUpdateAnnouncementUsecase>(),
      ),
    );
  }
}
