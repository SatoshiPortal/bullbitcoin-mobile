import 'dart:async';

import 'package:bb_mobile/core/price/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/bitcoin_price_failure.dart';
import 'package:bb_mobile/core/price/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/settings/domain/watch_currency_changes_usecase.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

part 'bitcoin_price_bloc.freezed.dart';
part 'bitcoin_price_event.dart';
part 'bitcoin_price_state.dart';

class BitcoinPriceBloc extends Bloc<BitcoinPriceEvent, BitcoinPriceState> {
  BitcoinPriceBloc({
    required this._getAvailableCurrenciesUsecase,
    required this._getSettingsUsecase,
    required this._convertSatsToCurrencyAmountUsecase,
    required this._watchCurrencyChangesUsecase,
  }) : super(const BitcoinPriceState()) {
    on<BitcoinPriceStarted>(_onStarted);
    on<BitcoinPriceFetched>(_onFetched);
    on<BitcoinPriceCurrencyChanged>(_onCurrencyChanged);

    // Watch for currency changes and emit a new state when the currency changes
    _currencyChangeSubscription = _watchCurrencyChangesUsecase.execute().listen(
      (currencyCode) {
        log.info('Currency changed to $currencyCode');
        add(BitcoinPriceCurrencyChanged(currencyCode: currencyCode));
      },
    );
  }

  final GetAvailableCurrenciesUsecase _getAvailableCurrenciesUsecase;
  final GetSettingsUsecase _getSettingsUsecase;
  final ConvertSatsToCurrencyAmountUsecase _convertSatsToCurrencyAmountUsecase;
  final WatchCurrencyChangesUsecase _watchCurrencyChangesUsecase;
  late final StreamSubscription<String> _currencyChangeSubscription;

  @override
  Future<void> close() async {
    await _currencyChangeSubscription.cancel();
    return super.close();
  }

  Future<void> _onStarted(
    BitcoinPriceStarted event,
    Emitter<BitcoinPriceState> emit,
  ) async {
    log.info('FiatCurrenciesStarted');

    emit(
      state.copyWith(loadingPrice: true, startupFailed: false, failure: null),
    );

    final String currency;
    final List<String> availableCurrencies;
    try {
      final settings = await _getSettingsUsecase.execute();
      currency = event.currency ?? settings.currencyCode;
      availableCurrencies = await _getAvailableCurrenciesUsecase.execute();
    } catch (e) {
      log.warning('BitcoinPriceStarted failed', error: e);
      emit(
        state.copyWith(
          failure: BitcoinPriceUnexpectedFailure(e.toString()),
          startupFailed: true,
          loadingPrice: false,
        ),
      );
      return;
    }

    // Kept even if the price fails below: neither needs the network, and the
    // currency settings row is disabled without them, so an offline start
    // left it dead until the app was restarted.
    emit(
      state.copyWith(
        currency: currency,
        availableCurrencies: availableCurrencies,
      ),
    );

    try {
      final price = await _convertSatsToCurrencyAmountUsecase.execute(
        currencyCode: currency,
      );

      // The currency changed while this was in flight: the price is for the
      // old one, and the change has fetched its own.
      if (state.currency != currency) return;

      if (price <= 0) {
        log.warning('Fiat rate invalid or zero for $currency');
        emit(
          state.copyWith(
            loadingPrice: false,
            startupFailed: true,
            failure: null,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          bitcoinPrice: price,
          startupFailed: false,
          failure: null,
          loadingPrice: false,
        ),
      );
    } catch (e) {
      log.warning('BitcoinPriceStarted failed', error: e);
      if (state.currency != currency) return;
      emit(
        state.copyWith(
          failure: BitcoinPriceUnexpectedFailure(e.toString()),
          startupFailed: true,
          loadingPrice: false,
        ),
      );
    }
  }

  Future<void> _onFetched(
    BitcoinPriceFetched event,
    Emitter<BitcoinPriceState> emit,
  ) async {
    log.info('BitcoinPriceFetched');

    final currency = state.currency;
    // Nothing loaded yet, e.g. the start-up read failed: load it all, not
    // just the price, or a refresh could never recover.
    if (currency == null || state.availableCurrencies == null) {
      // Only a full load is deduplicated: one already running (start-up, or
      // an earlier pull) will deliver it.
      if (state.loadingPrice) return;
      return _onStarted(const BitcoinPriceStarted(), emit);
    }

    try {
      final price = await _convertSatsToCurrencyAmountUsecase.execute(
        currencyCode: currency,
      );

      // The currency changed while this was in flight: the price is for the
      // old one, and the change has fetched its own.
      if (state.currency != currency) return;

      if (price <= 0) {
        emit(state.copyWith(failure: const BitcoinPriceInvalidRateFailure()));
        return;
      }

      emit(
        state.copyWith(
          bitcoinPrice: price,
          failure: null,
          startupFailed: false,
        ),
      );
    } catch (e) {
      // TODO: would it make sense to not emit a failure state here, but keep the
      //  previous success state as to be able to show an exchange rate allthough
      //  not the most recent one? If that makes sense, we can add the error directly
      //  to the success state. So the UI can show the exchange rate, but also show
      //  that it might not be the most recent one.
      //  (Adding a fetch and rate timestamp to the success can also help)
      log.warning('BitcoinPriceFetched failed', error: e);
      if (state.currency != currency) return;
      emit(
        state.copyWith(failure: BitcoinPriceUnexpectedFailure(e.toString())),
      );
    }
  }

  Future<void> _onCurrencyChanged(
    BitcoinPriceCurrencyChanged event,
    Emitter<BitcoinPriceState> emit,
  ) async {
    log.info('BitcoinPriceCurrencyChanged to ${event.currencyCode}');

    try {
      emit(state.copyWith(loadingPrice: true));

      final currency = event.currencyCode;
      final price = await _convertSatsToCurrencyAmountUsecase.execute(
        currencyCode: currency,
      );

      if (price <= 0) {
        log.warning(
          'Fiat rate invalid or zero after currency change to $currency',
        );
        emit(
          state.copyWith(
            bitcoinPrice: null,
            currency: currency,
            loadingPrice: false,
            failure: const BitcoinPriceInvalidRateFailure(),
            startupFailed: false,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          currency: currency,
          bitcoinPrice: price,
          loadingPrice: false,
          failure: null,
          startupFailed: false,
        ),
      );
    } catch (e) {
      log.warning('BitcoinPriceCurrencyChanged failed', error: e);
      emit(
        state.copyWith(
          bitcoinPrice: null,
          currency: event.currencyCode,
          loadingPrice: false,
          failure: BitcoinPriceUnexpectedFailure(e.toString()),
          startupFailed: false,
        ),
      );
    }
  }
}
