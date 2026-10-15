import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_account_info_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_exchange_preferences_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_exchange_statistics_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_secure_file_upload_status_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/update_exchange_preferences_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/upload_exchange_document_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/account_info_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/exchange_preferences_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/secure_file_upload_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/statistics_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/ui/screens/account_info_screen.dart';
import 'package:bb_mobile/features/exchange_settings/ui/screens/exchange_preferences_screen.dart';
import 'package:bb_mobile/features/exchange_settings/ui/screens/secure_file_upload_screen.dart';
import 'package:bb_mobile/features/exchange_settings/ui/screens/statistics_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export '../exchange_settings_locator.dart' show ExchangeSettingsLocator;
export '../ui/exchange_settings_router.dart'
    show ExchangeSettingsRoute, ExchangeSettingsRouter;

class ExchangeSettingsFacade {
  final GetAccountInfoUsecase _getAccountInfoUsecase;
  final GetExchangePreferencesUsecase _getPreferencesUsecase;
  final UpdateExchangePreferencesUsecase _updatePreferencesUsecase;
  final GetSecureFileUploadStatusUsecase _getUploadStatusUsecase;
  final GetExchangeStatisticsUsecase _getStatisticsUsecase;
  final UploadExchangeDocumentUsecase _uploadDocumentUsecase;

  const ExchangeSettingsFacade({
    required this._getAccountInfoUsecase,
    required this._getPreferencesUsecase,
    required this._updatePreferencesUsecase,
    required this._getUploadStatusUsecase,
    required this._getStatisticsUsecase,
    required this._uploadDocumentUsecase,
  });

  Widget buildAccountInfoScreen() => BlocProvider<AccountInfoCubit>(
    create: (_) =>
        AccountInfoCubit(getAccountInfoUsecase: _getAccountInfoUsecase),
    child: const AccountInfoScreen(),
  );

  Widget buildPreferencesScreen() => BlocProvider<ExchangePreferencesCubit>(
    create: (_) => ExchangePreferencesCubit(
      getExchangePreferencesUsecase: _getPreferencesUsecase,
      updateExchangePreferencesUsecase: _updatePreferencesUsecase,
    ),
    child: const ExchangePreferencesScreen(),
  );

  Widget buildSecureFileUploadScreen() => BlocProvider<SecureFileUploadCubit>(
    create: (_) => SecureFileUploadCubit(
      getUploadStatusUsecase: _getUploadStatusUsecase,
      uploadDocumentUsecase: _uploadDocumentUsecase,
    ),
    child: const SecureFileUploadScreen(),
  );

  Widget buildStatisticsScreen() => BlocProvider<StatisticsCubit>(
    create: (_) => StatisticsCubit(getStatisticsUsecase: _getStatisticsUsecase),
    child: const StatisticsScreen(),
  );
}
