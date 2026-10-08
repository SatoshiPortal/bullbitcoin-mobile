import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/announcements/data/announcement_dismissal_repository_impl.dart';
import 'package:bb_mobile/features/announcements/data/datasources/announcement_dismissal_datasource.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/dismiss_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/get_visible_announcements_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/watch_app_update_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/repositories/announcement_dismissal_repository.dart';
import 'package:bb_mobile/features/announcements/presentation/announcements_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/dismiss_recoverbull_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/watch_recoverbull_announcements_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/entities/recoverbull_announcement.dart';

class AnnouncementsLocator {
  static void setup(GetIt locator) {
    // Data
    locator.registerLazySingleton<AnnouncementDismissalDatasource>(
      () => AnnouncementDismissalDatasource(sqlite: locator<SqliteDatabase>()),
    );
    locator.registerLazySingleton<AnnouncementDismissalRepository>(
      () => AnnouncementDismissalRepositoryImpl(
        datasource: locator<AnnouncementDismissalDatasource>(),
      ),
    );

    // Use-cases
    locator.registerFactory<GetVisibleAnnouncementsUsecase>(
      () => GetVisibleAnnouncementsUsecase(
        locator<AnnouncementDismissalRepository>(),
        locator<SwapFacade>(),
      ),
    );
    locator.registerFactory<WatchAppUpdateAnnouncementUsecase>(
      () => WatchAppUpdateAnnouncementUsecase(locator<SwapFacade>()),
    );
    locator.registerFactory<DismissAnnouncementUsecase>(
      () => DismissAnnouncementUsecase(
        dismissalRepository: locator<AnnouncementDismissalRepository>(),
        dismissRecoverBull: locator.isRegistered<RecoverBullFeature>()
            ? DismissRecoverBullAnnouncementUsecase(
                locator<RecoverBullFeature>().attemptMonitoring,
              )
            : null,
      ),
    );
    if (locator.isRegistered<RecoverBullFeature>()) {
      locator.registerFactory<WatchRecoverBullAnnouncementsUsecase>(
        () => WatchRecoverBullAnnouncementsUsecase(
          locator<RecoverBullFeature>().attemptMonitoring,
        ),
      );
    }

    // Presentation
    locator.registerFactory<AnnouncementsCubit>(
      () => AnnouncementsCubit(
        getVisibleAnnouncementsUsecase:
            locator<GetVisibleAnnouncementsUsecase>(),
        dismissAnnouncementUsecase: locator<DismissAnnouncementUsecase>(),
        watchAppUpdateAnnouncementUsecase:
            locator<WatchAppUpdateAnnouncementUsecase>(),
        watchRecoverBullAnnouncementsUsecase:
            locator.isRegistered<WatchRecoverBullAnnouncementsUsecase>()
            ? locator<WatchRecoverBullAnnouncementsUsecase>()
            : const _EmptyRecoverBullAnnouncementsUsecase(),
      ),
    );
  }
}

final class _EmptyRecoverBullAnnouncementsUsecase
    implements WatchRecoverBullAnnouncementsUsecase {
  const _EmptyRecoverBullAnnouncementsUsecase();

  @override
  Stream<List<RecoverBullAnnouncement>> execute() =>
      const Stream<List<RecoverBullAnnouncement>>.empty();
}
