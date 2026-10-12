import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_exchange_statistics_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_secure_file_upload_status_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/upload_exchange_document_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/secure_file_upload_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/statistics_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/ui/screens/secure_file_upload_screen.dart';
import 'package:bb_mobile/features/exchange_settings/ui/screens/statistics_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export '../exchange_settings_locator.dart' show ExchangeSettingsLocator;
export '../ui/exchange_settings_router.dart'
    show ExchangeSettingsRoute, ExchangeSettingsRouter;

class ExchangeSettingsFacade {
  final GetSecureFileUploadStatusUsecase _getUploadStatusUsecase;
  final GetExchangeStatisticsUsecase _getStatisticsUsecase;
  final UploadExchangeDocumentUsecase _uploadDocumentUsecase;

  const ExchangeSettingsFacade({
    required this._getUploadStatusUsecase,
    required this._getStatisticsUsecase,
    required this._uploadDocumentUsecase,
  });

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
