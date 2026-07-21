import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/watch_payjoin_enabled_changes_usecase.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transactions_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/announcements/data/announcement_dismissal_repository_impl.dart';
import 'package:bb_mobile/features/announcements/data/datasources/announcement_dismissal_datasource.dart';
import 'package:bb_mobile/features/announcements/domain/dismiss_announcement_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/get_visible_announcements_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/repositories/announcement_dismissal_repository.dart';
import 'package:bb_mobile/features/announcements/presentation/announcements_cubit.dart';
import 'package:get_it/get_it.dart';

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
        settingsRepository: locator<SettingsRepository>(),
        getWalletTransactionsUsecase: locator<GetWalletTransactionsUsecase>(),
        getAutoSwapSettingsUsecase: locator<GetAutoSwapSettingsUsecase>(),
        dismissalRepository: locator<AnnouncementDismissalRepository>(),
      ),
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
        watchPayjoinEnabledChangesUsecase:
            locator<WatchPayjoinEnabledChangesUsecase>(),
        watchFinishedWalletSyncsUsecase:
            locator<WatchFinishedWalletSyncsUsecase>(),
      ),
    );
  }
}
