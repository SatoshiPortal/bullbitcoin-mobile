import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/check_exchange_api_key_exists_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/delete_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';

part 'exchange_settings_cubit.freezed.dart';
part 'exchange_settings_state.dart';

class ExchangeSettingsCubit extends Cubit<ExchangeSettingsState> {
  ExchangeSettingsCubit({
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
    required CheckExchangeApiKeyExistsUsecase checkExchangeApiKeyExistsUsecase,
    required DeleteExchangeApiKeyUsecase deleteExchangeApiKeyUsecase,
  }) : _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       _checkExchangeApiKeyExistsUsecase = checkExchangeApiKeyExistsUsecase,
       _deleteExchangeApiKeyUsecase = deleteExchangeApiKeyUsecase,
       super(const ExchangeSettingsState());

  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final CheckExchangeApiKeyExistsUsecase _checkExchangeApiKeyExistsUsecase;
  final DeleteExchangeApiKeyUsecase _deleteExchangeApiKeyUsecase;

  Future<void> init() async {
    try {
      emit(state.copyWith(status: ExchangeSettingsStatus.loading));

      final hasApiKey = await _checkExchangeApiKeyExistsUsecase.execute();

      if (!hasApiKey) {
        emit(state.copyWith(status: ExchangeSettingsStatus.noAuth));
        return;
      }

      final userSummary = await _getExchangeUserSummaryUsecase.execute();
      emit(
        state.copyWith(
          status: ExchangeSettingsStatus.success,
          userSummary: userSummary,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ExchangeSettingsStatus.error,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> logout() async {
    try {
      emit(state.copyWith(status: ExchangeSettingsStatus.loading));
      final webviewController = WebViewController();
      final cookieManager = WebviewCookieManager();
      await Future.wait([
        _deleteExchangeApiKeyUsecase.execute(),
        webviewController.clearCache(),
        webviewController.clearLocalStorage(),
        cookieManager.clearCookies(),
      ]);

      emit(
        state.copyWith(
          status: ExchangeSettingsStatus.noAuth,
          userSummary: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ExchangeSettingsStatus.error,
          error: e.toString(),
        ),
      );
    }
  }
}
