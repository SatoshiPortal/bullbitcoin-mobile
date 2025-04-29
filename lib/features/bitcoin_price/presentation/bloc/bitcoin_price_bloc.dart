import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'bitcoin_price_bloc.freezed.dart';
part 'bitcoin_price_event.dart';
part 'bitcoin_price_state.dart';

class BitcoinPriceBloc extends Bloc<BitcoinPriceEvent, BitcoinPriceState> {
  BitcoinPriceBloc({
    required GetAvailableCurrenciesUsecase getAvailableCurrenciesUsecase,
    required GetSettingsUsecase getSettingsUsecase,
    required ConvertSatsToCurrencyAmountUsecase
        convertSatsToCurrencyAmountUsecase,
  })  : _getAvailableCurrenciesUsecase = getAvailableCurrenciesUsecase,
        _getSettingsUsecase = getSettingsUsecase,
        _convertSatsToCurrencyAmountUsecase =
            convertSatsToCurrencyAmountUsecase,
        super(const BitcoinPriceState()) {
    on<BitcoinPriceStarted>(_onStarted);
    on<BitcoinPriceFetched>(_onFetched);
    on<BitcoinPriceCurrencyChanged>(_onCurrencyChanged);
  }

  final GetAvailableCurrenciesUsecase _getAvailableCurrenciesUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;

  Future<void> _onStarted(
    BitcoinPriceStarted event,
    Emitter<BitcoinPriceState> emit,
  ) async {
    debugPrint('FiatCurrenciesStarted');

    try {
      final settings = await _getSettingsUsecase.execute();
      final currency = event.currency ?? settings.currencyCode;
      final availableCurrencies =
          await _getAvailableCurrenciesUsecase.execute();

      final price = await _convertSatsToCurrencyAmountUsecase.execute(
        currencyCode: currency,
      );

      emit(
        BitcoinPriceState(
          currency: currency,
          availableCurrencies: availableCurrencies,
          bitcoinPrice: price,
        ),
      );
    } catch (e) {
      debugPrint(e.toString());
      emit(state.copyWith(error: e));
    }
  }

  Future<void> _onFetched(
    BitcoinPriceFetched event,
    Emitter<BitcoinPriceState> emit,
  ) async {
    debugPrint('BitcoinPriceFetched');

    try {
      final currency = state.currency;

      if (currency != null) {
        final price = await _convertSatsToCurrencyAmountUsecase.execute(
          currencyCode: currency,
        );

        emit(
          state.copyWith(
            bitcoinPrice: price,
          ),
        );
      }
    } catch (e) {
      debugPrint(e.toString());
      // TODO: would it make sense to not emit a failure state here, but keep the
      //  previous success state as to be able to show an exchange rate allthough
      //  not the most recent one? If that makes sense, we can add the error directly
      //  to the success state. So the UI can show the exchange rate, but also show
      //  that it might not be the most recent one.
      //  (Adding a fetch and rate timestamp to the success can also help)
      emit(state.copyWith(error: e));
    }
  }

  Future<void> _onCurrencyChanged(
    BitcoinPriceCurrencyChanged event,
    Emitter<BitcoinPriceState> emit,
  ) async {
    debugPrint('BitcoinPriceCurrencyChanged to ${event.currencyCode}');

    try {
      // The state should be in the success state, otherwise try to start the bloc
      //  again with the new currency in the event.
      // final successState = state as BitcoinPriceSuccess;
      final currency = event.currencyCode;
      // Get the exchange rate for the new currency
      final price = await _convertSatsToCurrencyAmountUsecase.execute(
        currencyCode: currency,
      );

      emit(
        state.copyWith(
          currency: currency,
          bitcoinPrice: price,
        ),
      );
    } catch (e) {
      debugPrint(e.toString());
      emit(state.copyWith(error: e));
    }
  }
}
