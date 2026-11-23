import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_account_info_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_exchange_preferences_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_exchange_statistics_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_secure_file_upload_status_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/update_exchange_preferences_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/upload_exchange_document_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/public/exchange_settings_facade.dart';
import 'package:exchange/exchange.dart';
import 'package:file_system/file_system.dart';
import 'package:get_it/get_it.dart';

class ExchangeSettingsLocator {
  static void setup(GetIt locator) {
    _registerFeatureUsecases(locator);
    _registerFacade(locator);
  }

  /// The feature's own use-cases. Each wraps a shared `core/exchange`
  /// use-case that still throws, and is therefore the `try/catch` boundary
  /// that turns a raw exception into a sanitized `ExchangeSettingsFailure`.
  static void _registerFeatureUsecases(GetIt locator) {
    locator.registerFactory<GetAccountInfoUsecase>(
      () => GetAccountInfoUsecase(
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
      ),
    );

    locator.registerFactory<GetExchangePreferencesUsecase>(
      () => GetExchangePreferencesUsecase(
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
      ),
    );

    locator.registerFactory<UpdateExchangePreferencesUsecase>(
      () => UpdateExchangePreferencesUsecase(
        exchangeFacade: locator<ExchangeFacade>(),
      ),
    );

    locator.registerFactory<GetExchangeStatisticsUsecase>(
      () => GetExchangeStatisticsUsecase(exchange: locator<Exchange>()),
    );

    locator.registerFactory<GetSecureFileUploadStatusUsecase>(
      () => GetSecureFileUploadStatusUsecase(
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
      ),
    );

    locator.registerFactory<UploadExchangeDocumentUsecase>(
      () => UploadExchangeDocumentUsecase(
        fileSystem: const FileSystem.open(),
        exchange: locator<Exchange>(),
      ),
    );
  }

  static void _registerFacade(GetIt locator) {
    locator.registerLazySingleton<ExchangeSettingsFacade>(
      () => ExchangeSettingsFacade(
        getAccountInfoUsecase: locator<GetAccountInfoUsecase>(),
        getPreferencesUsecase: locator<GetExchangePreferencesUsecase>(),
        updatePreferencesUsecase: locator<UpdateExchangePreferencesUsecase>(),
        getUploadStatusUsecase: locator<GetSecureFileUploadStatusUsecase>(),
        getStatisticsUsecase: locator<GetExchangeStatisticsUsecase>(),
        uploadDocumentUsecase: locator<UploadExchangeDocumentUsecase>(),
      ),
    );
  }
}
