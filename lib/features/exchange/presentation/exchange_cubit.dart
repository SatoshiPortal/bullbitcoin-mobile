import 'dart:async';

import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/delete_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExchangeCubit extends Cubit<ExchangeState> {
  ExchangeCubit({
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
    required SaveExchangeApiKeyUsecase saveExchangeApiKeyUsecase,
    required DeleteExchangeApiKeyUsecase deleteExchangeApiKeyUsecase,
  }) : _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       _saveExchangeApiKeyUsecase = saveExchangeApiKeyUsecase,
       _deleteExchangeApiKeyUsecase = deleteExchangeApiKeyUsecase,
       super(const ExchangeState());

  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final SaveExchangeApiKeyUsecase _saveExchangeApiKeyUsecase;
  final DeleteExchangeApiKeyUsecase _deleteExchangeApiKeyUsecase;

  Future<void> fetchUserSummary() async {
    try {
      // Clear any previous exceptions
      emit(
        state.copyWith(apiKeyException: null, getUserSummaryException: null),
      );

      final userSummary = await _getExchangeUserSummaryUsecase.execute();

      emit(state.copyWith(userSummary: userSummary));
    } catch (e) {
      log.severe('Error during init: $e');
      if (e is ApiKeyException) {
        emit(state.copyWith(apiKeyException: e));
      } else if (e is GetExchangeUserSummaryException) {
        emit(state.copyWith(getUserSummaryException: e));
      }
    }
  }

  Future<void> storeApiKey(Map<String, dynamic> apiKeyData) async {
    try {
      log.info('Storing API key: $apiKeyData');

      // Clear any previous exceptions
      emit(state.copyWith(saveApiKeyException: null));

      await _saveExchangeApiKeyUsecase.execute(apiKeyResponseData: apiKeyData);
      log.fine('API key successfully stored');

      // Now that the API key is stored, we can try to fetch the user summary
      //  again.
      await fetchUserSummary();
    } catch (e) {
      log.severe('Error in storeApiKey: $e');
      if (e is SaveExchangeApiKeyException) {
        emit(state.copyWith(saveApiKeyException: e));
      }
    }
  }

  Future<void> logout() async {
    try {
      log.info('Logging out from exchange');

      // Clear any previous exceptions
      emit(state.copyWith(deleteApiKeyException: null));

      await _deleteExchangeApiKeyUsecase.execute();
      log.fine('Successfully logged out from exchange');

      // Now that the user should be logged out, try to fetch the user summary
      // again, which should result in an ApiKeyException now.
      await fetchUserSummary();
    } catch (e) {
      log.severe('Error during logout: $e');
      if (e is DeleteExchangeApiKeyException) {
        emit(state.copyWith(deleteApiKeyException: e));
      }
    }
  }
}
