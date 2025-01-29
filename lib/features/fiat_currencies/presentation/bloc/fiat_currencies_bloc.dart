import 'package:bb_mobile/features/fiat_currencies/domain/usecases/fetch_bitcoin_price_usecase.dart';
import 'package:bb_mobile/features/fiat_currencies/domain/usecases/get_available_fiat_currencies.dart';
import 'package:bb_mobile/features/fiat_currencies/domain/usecases/get_fiat_currency_usecase.dart';
import 'package:bb_mobile/features/fiat_currencies/domain/usecases/set_fiat_currency_usecase.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'fiat_currencies_bloc.freezed.dart';
part 'fiat_currencies_event.dart';
part 'fiat_currencies_state.dart';

class FiatCurrenciesBloc
    extends Bloc<FiatCurrenciesEvent, FiatCurrenciesState> {
  FiatCurrenciesBloc({
    required GetAvailableFiatCurrenciesUseCase
        getAvailableFiatCurrenciesUseCase,
    required GetFiatCurrencyUseCase getFiatCurrencyUseCase,
    required SetFiatCurrencyUseCase setFiatCurrencyUseCase,
    required FetchBitcoinPriceUseCase fetchBitcoinPriceUseCase,
  })  : _getAvailableFiatCurrenciesUseCase = getAvailableFiatCurrenciesUseCase,
        _getFiatCurrencyUseCase = getFiatCurrencyUseCase,
        _setFiatCurrencyUseCase = setFiatCurrencyUseCase,
        _fetchBitcoinPriceUseCase = fetchBitcoinPriceUseCase,
        super(const FiatCurrenciesState.initial()) {
    on<FiatCurrenciesStarted>(_onStarted);
    on<FiatCurrenciesBitcoinPriceFetched>(_onBitcoinPriceFetched);
    on<FiatCurrenciesBitcoinPriceCurrencyChanged>(
        _onBitcoinPriceCurrencyChanged);
  }

  final GetAvailableFiatCurrenciesUseCase _getAvailableFiatCurrenciesUseCase;
  final GetFiatCurrencyUseCase _getFiatCurrencyUseCase;
  final SetFiatCurrencyUseCase _setFiatCurrencyUseCase;
  final FetchBitcoinPriceUseCase _fetchBitcoinPriceUseCase;

  Future<void> _onStarted(
    FiatCurrenciesStarted event,
    Emitter<FiatCurrenciesState> emit,
  ) async {
    debugPrint('FiatCurrenciesStarted');

    try {
      final currency =
          event.bitcoinPriceCurrency ?? await _getFiatCurrencyUseCase.execute();
      final availableCurrencies =
          await _getAvailableFiatCurrenciesUseCase.execute();

      if (!availableCurrencies.contains(currency)) {
        throw PriceForCurrencyNotAvailableException(currencyCode: currency);
      }

      final price = await _fetchBitcoinPriceUseCase.execute(currency);

      emit(
        FiatCurrenciesState.success(
          bitcoinPriceCurrency: currency,
          availableCurrencies: availableCurrencies,
          bitcoinPrice: price,
        ),
      );
    } catch (e) {
      debugPrint(e.toString());
      emit(FiatCurrenciesState.failure(e));
    }
  }

  Future<void> _onBitcoinPriceFetched(
    FiatCurrenciesBitcoinPriceFetched event,
    Emitter<FiatCurrenciesState> emit,
  ) async {
    debugPrint('BitcoinPriceFetched');

    try {
      // The state should be in the success state, otherwise try to start the bloc
      //  again with the new currency in the event.
      final successState = state as FiatCurrenciesSuccess;
      final currency = successState.bitcoinPriceCurrency;
      final price = await _fetchBitcoinPriceUseCase.execute(currency);

      emit(
        successState.copyWith(
          bitcoinPrice: price,
        ),
      );
    } catch (e) {
      debugPrint(e.toString());
      // TODO: would it make sense to not emit a failure state here, but keep the
      //  previous success state as to be able to show an exchange rate allthough
      //  not the most recent one? If that makes sense, we can add the error directly
      //  to the success state. So the UI can show the exchange rate, but also show
      //  that it might not be the most recent one.
      //  (Adding a fetch and rate timestamp to the success can also help)
      emit(FiatCurrenciesState.failure(e));
    }
  }

  Future<void> _onBitcoinPriceCurrencyChanged(
    FiatCurrenciesBitcoinPriceCurrencyChanged event,
    Emitter<FiatCurrenciesState> emit,
  ) async {
    debugPrint('BitcoinPriceCurrencyChanged to ${event.currencyCode}');

    try {
      // The state should be in the success state, otherwise try to start the bloc
      //  again with the new currency in the event.
      final successState = state as FiatCurrenciesSuccess;
      final currency = event.currencyCode;
      // Get the exchange rate for the new currency
      final price = await _fetchBitcoinPriceUseCase.execute(currency);

      if (event.save) {
        await _setFiatCurrencyUseCase.execute(currency);
      }

      emit(
        successState.copyWith(
          bitcoinPriceCurrency: currency,
          bitcoinPrice: price,
        ),
      );
    } catch (e) {
      debugPrint(e.toString());
      emit(FiatCurrenciesState.failure(e));
    }
  }
}

class PriceForCurrencyNotAvailableException implements Exception {
  final String message;

  PriceForCurrencyNotAvailableException({
    required String currencyCode,
  }) : message = 'No price available for currency $currencyCode';
}
