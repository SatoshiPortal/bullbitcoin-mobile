import 'package:bb_mobile/core/models/fiat_currency_model.dart';
import 'package:bb_mobile/features/currencies/domain/repositories/fiat_currencies_repository.dart';
import 'package:bb_mobile/features/settings/domain/repositories/settings_repository.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'currencies_event.dart';
part 'currencies_state.dart';

class CurrenciesBloc extends Bloc<CurrenciesEvent, CurrenciesState> {
  CurrenciesBloc({
    required FiatCurrenciesRepository fiatCurrenciesRepository,
    required SettingsRepository settingsRepository,
    String?
        currency, // Pass a currency if you want to use another currency than the one saved in the settings
  })  : _currenciesRepository = fiatCurrenciesRepository,
        _settingsRepository = settingsRepository,
        _currency = currency,
        super(const CurrenciesInitial()) {
    on<CurrenciesFetched>(_onFetched);
    on<CurrenciesBitcoinPriceCurrencyChanged>(_onCurrencyChanged);
  }

  final String? _currency;
  final SettingsRepository _settingsRepository;
  final FiatCurrenciesRepository _currenciesRepository;

  Future<void> _onFetched(
    CurrenciesFetched event,
    Emitter<CurrenciesState> emit,
  ) async {
    debugPrint('Fetching currencies');

    try {
      final currency =
          _currency ?? await _settingsRepository.getDefaultCurrency();
      final price = await _currenciesRepository.getBitcoinPrice(currencyCode);
      emit(CurrenciesSuccess(
        availableCurrencies:
            await _currenciesRepository.getAvailableCurrencies(),
        bitcoinPriceCurrencyCode: currency,
        bitcoinPrice: price,
      ));
    } catch (e) {
      emit(const CurrenciesLoadFailure());
    }
  }

  Future<void> _onCurrencyChanged(
    CurrenciesBitcoinPriceCurrencyChanged event,
    Emitter<CurrenciesState> emit,
  ) async {
    debugPrint('Currency changed to ${event.currency}');

    try {
      final currency = event.currencyCode;
      // Get the exchange rate for the new currency
      final price = await _currenciesRepository.getBitcoinPrice(currency);
      // Save the new currency as the default currency
      await _settingsRepository.setDefaultCurrency(currency);
      // If correctly saved, emit the new exchange rate
      emit(
        state.copyWith(
          bitcoinPriceCurrencyCode: currency,
          bitcoinPrice: price,
        ),
      );
    } catch (e) {
      emit(const CurrenciesFailure(e));
    }
  }
}
