import 'package:bitcoin_price/src/domain/bitcoin_price_failure.dart';
import 'package:bitcoin_price/src/domain/usecases/watch_price_currency_usecase.dart';
import 'package:bitcoin_price/src/domain/usecases/read_price_currency_usecase.dart';
import 'package:bitcoin_price/src/domain/usecases/watch_bitcoin_price_amount_display_usecase.dart';

import 'dart:async';

import 'package:bull_pricer/bull_pricer.dart';
import 'package:bitcoin_price/src/domain/usecases/get_bitcoin_price_usecase.dart';
import 'package:preferences/preferences.dart' show AmountDisplayPreferences;

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';
import 'package:primitives/primitives.dart'
    show BitcoinUnit, Err, Ok, ConvertAmount, Result;

part 'bitcoin_price_bloc.freezed.dart';
part 'bitcoin_price_event.dart';
part 'bitcoin_price_state.dart';

class BitcoinPriceBloc extends Bloc<BitcoinPriceEvent, BitcoinPriceState> {
  BitcoinPriceBloc({
    WatchBitcoinPriceAmountDisplayUsecase? watchAmountDisplayUsecase,
    required this._readPriceCurrencyUsecase,
    required this._getBitcoinPriceUsecase,
    required this._watchPriceCurrencyUsecase,
    BitcoinPriceState initialState = const BitcoinPriceState(),
  }) : super(initialState) {
    on<_BitcoinPriceAmountDisplayChanged>((event, emit) {
      emit(state.copyWith(amountDisplay: event.preferences));
    });
    _amountDisplaySubscription = watchAmountDisplayUsecase?.execute().listen((
      result,
    ) {
      if (!isClosed) {
        add(
          _BitcoinPriceAmountDisplayChanged(
            result.fold((value) => value, (_) => null),
          ),
        );
      }
    });
    on<BitcoinPriceStarted>(_onStarted);
    on<BitcoinPriceFetched>(_onFetched);
    on<BitcoinPriceCurrencyChanged>(_onCurrencyChanged);

    // Watch for currency changes and emit a new state when the currency changes
    _currencyChangeSubscription = _watchPriceCurrencyUsecase.execute().listen((
      result,
    ) {
      if (result case Ok(value: final currencyCode) when !isClosed) {
        log.info('Currency changed to $currencyCode');
        add(BitcoinPriceCurrencyChanged(currencyCode: currencyCode));
      }
    });
  }

  late final StreamSubscription<
    Result<AmountDisplayPreferences, BitcoinPriceFailure>
  >?
  _amountDisplaySubscription;
  final ReadPriceCurrencyUsecase _readPriceCurrencyUsecase;
  final GetBitcoinPriceUsecase _getBitcoinPriceUsecase;
  final WatchPriceCurrencyUsecase _watchPriceCurrencyUsecase;
  late final StreamSubscription<Result<String, BitcoinPriceFailure>>
  _currencyChangeSubscription;

  /// The currency whose price is being fetched by a currency change, so a
  /// burst of the same change waits for that one request instead of sending
  /// its own.
  ({String code, Future<Result<void, BitcoinPriceFailure>> result})?
  _currencyInFlight;
  Future<Result<void, BitcoinPriceFailure>>? _startupInFlight;

  /// Counts currency changes, so only the latest one may publish its price:
  /// an answer for a currency the user has since left must not overwrite the
  /// newer one.
  int _currencyRequest = 0;

  Future<Result<void, BitcoinPriceFailure>> refresh({
    bool onlyIfUnavailable = false,
  }) {
    final completion = Completer<Result<void, BitcoinPriceFailure>>();
    add(
      BitcoinPriceFetched(
        onlyIfUnavailable: onlyIfUnavailable,
        completion: completion,
      ),
    );
    return completion.future;
  }

  Future<Result<void, BitcoinPriceFailure>> quoteInCurrency(String currency) {
    final completion = Completer<Result<void, BitcoinPriceFailure>>();
    add(
      BitcoinPriceCurrencyChanged(
        currencyCode: currency,
        completion: completion,
      ),
    );
    return completion.future;
  }

  @override
  Future<void> close() async {
    await _amountDisplaySubscription?.cancel();
    await _currencyChangeSubscription.cancel();
    return super.close();
  }

  Future<void> _onStarted(
    BitcoinPriceStarted event,
    Emitter<BitcoinPriceState> emit,
  ) async {
    await _start(event.currency, emit);
  }

  Future<Result<void, BitcoinPriceFailure>> _start(
    String? requestedCurrency,
    Emitter<BitcoinPriceState> emit,
  ) => _startupInFlight ??= _loadInitialPrice(requestedCurrency, emit)
      .whenComplete(() {
        _startupInFlight = null;
      });

  Future<Result<void, BitcoinPriceFailure>> _loadInitialPrice(
    String? requestedCurrency,
    Emitter<BitcoinPriceState> emit,
  ) async {
    log.info('FiatCurrenciesStarted');

    emit(
      state.copyWith(loadingPrice: true, startupFailed: false, failure: null),
    );

    final currencyResult = await _readPriceCurrencyUsecase.execute();
    final String currency;
    switch (currencyResult) {
      case Ok(:final value):
        currency = requestedCurrency ?? value;
      case Err(:final failure):
        emit(
          state.copyWith(
            failure: failure,
            startupFailed: true,
            loadingPrice: false,
          ),
        );
        return Err(failure);
    }

    // Kept even if the price fails below: neither needs the network, and the
    // currency settings row is disabled without them, so an offline start
    // left it dead until the app was restarted.
    emit(
      state.copyWith(
        currency: currency,
        availableCurrencies: SupportedCurrency.codes,
      ),
    );

    final price = await _getBitcoinPriceUsecase.execute(currencyCode: currency);

    // The currency changed while this was in flight: the price is for the
    // old one, and the change has fetched its own.
    if (state.currency != currency) return price.map<void>((_) {});

    switch (price) {
      case Ok(:final value):
        emit(
          state.copyWith(
            bitcoinPrice: value,
            startupFailed: false,
            failure: null,
            loadingPrice: false,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            // Offline at start-up is shown by startupFailed alone; any other
            // failure is shown as on a refresh.
            failure: failure is BitcoinPriceNetworkFailure ? null : failure,
            startupFailed: true,
            loadingPrice: false,
          ),
        );
    }
    return price.map<void>((_) {});
  }

  Future<void> _onFetched(
    BitcoinPriceFetched event,
    Emitter<BitcoinPriceState> emit,
  ) async {
    final result = _fetchPrice(event.onlyIfUnavailable, emit);
    event.completion?.complete(result);
    await result;
  }

  Future<Result<void, BitcoinPriceFailure>> _fetchPrice(
    bool onlyIfUnavailable,
    Emitter<BitcoinPriceState> emit,
  ) async {
    if (onlyIfUnavailable && state.hasValidFiatRate) {
      return const Ok(null);
    }

    final loadingPrice = _currencyInFlight?.result ?? _startupInFlight;
    if (onlyIfUnavailable && state.loadingPrice && loadingPrice != null) {
      return loadingPrice;
    }

    log.info('BitcoinPriceFetched');

    final currency = state.currency;
    // Nothing loaded yet, e.g. the start-up read failed: load it all, not
    // just the price, or a refresh could never recover.
    if (currency == null || state.availableCurrencies == null) {
      // Only a full load is deduplicated: one already running (start-up, or
      // an earlier pull) will deliver it.
      return loadingPrice ?? _start(null, emit);
    }

    final price = await _getBitcoinPriceUsecase.execute(currencyCode: currency);

    // The currency changed while this was in flight: the price is for the
    // old one, and the change has fetched its own.
    if (state.currency != currency) return price.map<void>((_) {});

    switch (price) {
      case Ok(:final value):
        emit(
          state.copyWith(
            bitcoinPrice: value,
            failure: null,
            startupFailed: false,
          ),
        );
      // A refresh only reaches the pricer once the cached price is over a
      // minute old, so the price on screen is outdated: with no answer, show
      // no price rather than that one.
      case Err(:final failure):
        emit(state.copyWith(bitcoinPrice: null, failure: failure));
    }
    return price.map<void>((_) {});
  }

  Future<void> _onCurrencyChanged(
    BitcoinPriceCurrencyChanged event,
    Emitter<BitcoinPriceState> emit,
  ) async {
    final currency = event.currencyCode;
    final inFlight = _currencyInFlight;
    final Future<Result<void, BitcoinPriceFailure>> result;
    if (inFlight != null && inFlight.code == currency) {
      result = inFlight.result;
    } else {
      result = _loadCurrencyPrice(currency, ++_currencyRequest, emit);
      _currencyInFlight = (code: currency, result: result);
    }
    event.completion?.complete(result);
    await result;
  }

  Future<Result<void, BitcoinPriceFailure>> _loadCurrencyPrice(
    String currency,
    int request,
    Emitter<BitcoinPriceState> emit,
  ) async {
    log.info('BitcoinPriceCurrencyChanged to $currency');

    try {
      emit(state.copyWith(loadingPrice: true));

      final price = await _getBitcoinPriceUsecase.execute(
        currencyCode: currency,
      );
      if (request != _currencyRequest) return price.map<void>((_) {});

      emit(
        state.copyWith(
          currency: currency,
          bitcoinPrice: switch (price) {
            Ok(:final value) => value,
            Err() => null,
          },
          loadingPrice: false,
          failure: switch (price) {
            Ok() => null,
            Err(:final failure) => failure,
          },
          startupFailed: false,
        ),
      );
      return price.map<void>((_) {});
    } finally {
      // Only the latest request owns the marker: an earlier one finishing,
      // even for the same currency, must not end the sharing of the latest.
      if (request == _currencyRequest) _currencyInFlight = null;
    }
  }
}
