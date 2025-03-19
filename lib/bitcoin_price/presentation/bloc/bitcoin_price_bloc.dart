import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/usecases/get_currency_usecase.dart';
import 'package:bb_mobile/bitcoin_price/domain/usecases/fetch_bitcoin_price_usecase.dart';
import 'package:bb_mobile/bitcoin_price/domain/usecases/get_available_fiat_currencies.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'bitcoin_price_bloc.freezed.dart';
part 'bitcoin_price_event.dart';
part 'bitcoin_price_state.dart';

class BitcoinPriceBloc extends Bloc<BitcoinPriceEvent, BitcoinPriceState> {
  BitcoinPriceBloc({
    required GetAvailableFiatCurrenciesUsecase
        getAvailableFiatCurrenciesUsecase,
    required GetCurrencyUsecase getCurrencyUsecase,
    required FetchBitcoinPriceUsecase fetchBitcoinPriceUsecase,
  })  : _getAvailableFiatCurrenciesUsecase = getAvailableFiatCurrenciesUsecase,
        _getCurrencyUsecase = getCurrencyUsecase,
        _fetchBitcoinPriceUsecase = fetchBitcoinPriceUsecase,
        super(const BitcoinPriceState()) {
    on<BitcoinPriceStarted>(_onStarted);
    on<BitcoinPriceFetched>(_onFetched);
    on<BitcoinPriceCurrencyChanged>(_onCurrencyChanged);
  }

  final GetAvailableFiatCurrenciesUsecase _getAvailableFiatCurrenciesUsecase;
  final GetCurrencyUsecase _getCurrencyUsecase;
  final FetchBitcoinPriceUsecase _fetchBitcoinPriceUsecase;

  Future<void> _onStarted(
    BitcoinPriceStarted event,
    Emitter<BitcoinPriceState> emit,
  ) async {
    debugPrint('FiatCurrenciesStarted');

    try {
      // final currency = event.currency ?? await _getCurrencyUsecase.execute();
      // final availableCurrencies =
      //     await _getAvailableFiatCurrenciesUsecase.execute();

      // if (!availableCurrencies.contains(currency)) {
      //   throw PriceForCurrencyNotAvailableException(currencyCode: currency);
      // }
      const currency = 'CAD';
      final price = await _fetchBitcoinPriceUsecase.execute(currency);

      emit(
        BitcoinPriceState(
          currency: currency,
          // availableCurrencies: availableCurrencies,
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
      // The state should be in the success state, otherwise try to start the bloc
      //  again with the new currency in the event.
      // final successState = state as BitcoinPriceSuccess;

      final price = await _fetchBitcoinPriceUsecase.execute(state.currency!);

      emit(
        state.copyWith(
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
      final price = await _fetchBitcoinPriceUsecase.execute(currency);

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

class PriceForCurrencyNotAvailableException implements Exception {
  final String message;

  PriceForCurrencyNotAvailableException({
    required String currencyCode,
  }) : message = 'No price available for currency $currencyCode';
}
