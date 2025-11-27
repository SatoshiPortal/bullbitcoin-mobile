import 'package:bb_mobile/core/exchange/domain/entity/composite_rate_history.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_composite_rate_history_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'price_chart_bloc.freezed.dart';
part 'price_chart_event.dart';
part 'price_chart_state.dart';

class PriceChartBloc extends Bloc<PriceChartEvent, PriceChartState> {
  PriceChartBloc({
    required GetSettingsUsecase getSettingsUsecase,
    required GetCompositeRateHistoryUsecase getCompositeRateHistoryUsecase,
  }) : _getSettingsUsecase = getSettingsUsecase,
       _getCompositeRateHistoryUsecase = getCompositeRateHistoryUsecase,
       super(const PriceChartState()) {
    on<PriceChartStarted>(_onStarted);
    on<PriceChartDataPointSelected>(_onDataPointSelected);
    on<PriceChartClosed>(_onClosed);
    on<PriceChartRefreshAllRates>(_onRefreshAllRates);
  }

  final GetSettingsUsecase _getSettingsUsecase;
  final GetCompositeRateHistoryUsecase _getCompositeRateHistoryUsecase;

  Future<void> _onStarted(
    PriceChartStarted event,
    Emitter<PriceChartState> emit,
  ) async {
    try {
      final settings = await _getSettingsUsecase.execute();
      final currency = event.currency ?? settings.currencyCode;

      emit(state.copyWith(currency: currency, isLoading: true));

      final compositeRateHistory = await _getCompositeRateHistoryUsecase
          .execute(fromCurrency: currency, toCurrency: 'BTC');

      final allRates = compositeRateHistory.getAllRates();
      final hasLocalData = allRates.isNotEmpty;
      final isValid = compositeRateHistory.isValid();

      emit(
        state.copyWith(
          currency: currency,
          compositeRateHistory: isValid ? compositeRateHistory : null,
          isLoading: !hasLocalData || !isValid,
        ),
      );

      if (!isValid || !hasLocalData) {
        add(PriceChartRefreshAllRates(currency: currency));
      }
    } catch (e) {
      log.severe('[PriceChartBloc] _onStarted error: $e');
      emit(state.copyWith(error: e, isLoading: false));
    }
  }

  void _onDataPointSelected(
    PriceChartDataPointSelected event,
    Emitter<PriceChartState> emit,
  ) {
    emit(state.copyWith(selectedDataPointIndex: event.index));
  }

  void _onClosed(PriceChartClosed event, Emitter<PriceChartState> emit) {
    emit(const PriceChartState());
  }

  Future<void> _onRefreshAllRates(
    PriceChartRefreshAllRates event,
    Emitter<PriceChartState> emit,
  ) async {
    try {
      final settings = await _getSettingsUsecase.execute();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? locator<ExchangeRateRepository>(
                instanceName: 'testnetExchangeRateRepository',
              )
              : locator<ExchangeRateRepository>(
                instanceName: 'mainnetExchangeRateRepository',
              );

      await repo.refreshAllRateHistory(
        fromCurrency: event.currency,
        toCurrency: 'BTC',
      );

      final updatedCompositeRateHistory = await _getCompositeRateHistoryUsecase
          .execute(fromCurrency: event.currency, toCurrency: 'BTC');

      if (state.currency == event.currency) {
        final allRates = updatedCompositeRateHistory.getAllRates();
        final currentSelectedIndex = state.selectedDataPointIndex;
        final normalizedSelectedIndex =
            currentSelectedIndex != null &&
                    currentSelectedIndex < allRates.length
                ? currentSelectedIndex
                : null;

        emit(
          state.copyWith(
            compositeRateHistory: updatedCompositeRateHistory,
            selectedDataPointIndex: normalizedSelectedIndex,
            isLoading: false,
          ),
        );
      }
    } catch (e) {
      log.warning('[PriceChartBloc] _onRefreshAllRates error: $e');
      if (state.currency == event.currency) {
        emit(state.copyWith(isLoading: false));
      }
    }
  }
}
