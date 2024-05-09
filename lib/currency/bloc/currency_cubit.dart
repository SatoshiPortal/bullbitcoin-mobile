import 'dart:convert';

import 'package:bb_mobile/_model/currency.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/currency/bloc/currency_state.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CurrencyCubit extends Cubit<CurrencyState> {
  CurrencyCubit({
    required HiveStorage hiveStorage,
    required BullBitcoinAPI bbAPI,
    CurrencyCubit? defaultCurrencyCubit,
  })  : _defaultCurrencyCubit = defaultCurrencyCubit,
        _bbAPI = bbAPI,
        _hiveStorage = hiveStorage,
        super(const CurrencyState()) {
    init();
    if (_defaultCurrencyCubit == null)
      loadCurrencies();
    else {
      reset();
      loadCurrencyForAmount();
    }
  }

  final HiveStorage _hiveStorage;
  final BullBitcoinAPI _bbAPI;
  final CurrencyCubit? _defaultCurrencyCubit;

  @override
  void onChange(Change<CurrencyState> change) {
    super.onChange(change);
    if (_defaultCurrencyCubit != null) return;
    _hiveStorage.saveValue(
      key: StorageKeys.currency,
      value: jsonEncode(change.nextState.toJson()),
    );
  }

  Future<void> init() async {
    if (_defaultCurrencyCubit != null) {
      emit(_defaultCurrencyCubit.state);
      reset();
      loadCurrencyForAmount();
      return;
    }
    Future.delayed(const Duration(milliseconds: 200));
    final (result, err) = await _hiveStorage.getValue(StorageKeys.currency);
    if (err != null) return;

    final currency =
        CurrencyState.fromJson(jsonDecode(result!) as Map<String, dynamic>);
    emit(currency);
    loadCurrencies();
  }

  void loadCurrencyForAmount() async {
    await Future.delayed(300.ms);
    final updatedCurrenciess = state.updatedCurrencyList();
    final selectedCurrency = updatedCurrenciess.firstWhere(
      (element) => element.name == (state.unitsInSats ? 'sats' : 'btc'),
    );

    emit(state.copyWith(currency: selectedCurrency));
  }

  void toggleUnitsInSats() {
    emit(state.copyWith(unitsInSats: !state.unitsInSats));
  }

  void changeDefaultCurrency(Currency currency) =>
      emit(state.copyWith(defaultFiatCurrency: currency));

  void loadCurrencies() async {
    emit(state.copyWith(loadingCurrency: true));
    final (cad, _) = await _bbAPI.getExchangeRate(toCurrency: 'CAD');
    final (usd, _) = await _bbAPI.getExchangeRate(toCurrency: 'USD');
    final (crc, _) = await _bbAPI.getExchangeRate(toCurrency: 'CRC');
    final (inr, _) = await _bbAPI.getExchangeRate(toCurrency: 'INR');
    final (eur, _) = await _bbAPI.getExchangeRate(toCurrency: 'EUR');

    final results = [
      if (cad != null) cad,
      if (usd != null) usd,
      if (crc != null) crc,
      if (inr != null) inr,
      if (eur != null) eur,
    ];

    emit(
      state.copyWith(
        currency: results.isNotEmpty ? results.first : state.currency,
        defaultFiatCurrency: state.defaultFiatCurrency ??
            (results.isNotEmpty ? results.first : null),
        currencyList: results.isNotEmpty ? results : state.currencyList,
        loadingCurrency: false,
        lastUpdatedCurrency: DateTime.now(),
      ),
    );

    // if (state.currency != null) {
    //   final currency = results.firstWhere(
    //     (_) => _.name == state.currency!.name,
    //     orElse: () => state.currency!,
    //   );
    //   emit(state.copyWith(currency: currency, defaultFiatCurrency: currency));
    //   if (results.isEmpty && state.currencyList == null)
    //     emit(state.copyWith(currencyList: [currency]));
    // }

    if (state.defaultFiatCurrency != null) {
      final currency = results.firstWhere(
        (_) => _.name == state.defaultFiatCurrency!.name,
        orElse: () => state.defaultFiatCurrency!,
      );
      emit(state.copyWith(defaultFiatCurrency: currency));
    }
  }

  void updateAmountCurrency(String currency) {
    final currencies = state.updatedCurrencyList();
    final selectedCurrency =
        currencies.firstWhere((_) => _.name.toLowerCase() == currency);

    if (currency == 'btc' || currency == 'sats')
      emit(
        state.copyWith(
          fiatSelected: false,
          currency: selectedCurrency,
          unitsInSats: currency == 'sats',
          tempAmount: '',
        ),
      );
    else
      emit(
        state.copyWith(
          fiatSelected: true,
          currency: selectedCurrency,
          unitsInSats: false,
          tempAmount: '',
        ),
      );
    convertAmtOnCurrencyChange();
  }

  void convertAmtOnCurrencyChange() async {
    await Future.delayed(300.ms);
    final satsAmt = state.amount;
    String amt = '';
    if (state.fiatSelected) {
      final currency = state.currency;
      final fiatAmt = currency!.price! * (satsAmt / 100000000);
      amt = fiatAmt.toStringAsFixed(2);
    } else {
      if (state.unitsInSats)
        amt = satsAmt.toString();
      else
        amt = (satsAmt / 100000000).toStringAsFixed(8);
    }
    emit(state.copyWith(tempAmount: amt));
    updateAmount(amt);
  }

  void btcToCurrentTempAmount(double btcAmt) {
    String amt = '';
    if (state.fiatSelected) {
      final currency = state.currency;
      final fiatAmt = currency!.price! * btcAmt;
      amt = fiatAmt.toStringAsFixed(2);
    } else {
      if (state.unitsInSats)
        amt = (btcAmt * 100000000).toStringAsFixed(0);
      else
        amt = btcAmt.toString();
    }
    emit(state.copyWith(tempAmount: amt));
    updateAmount(amt);
  }

  void updateAmount(String txt) {
    var clean = txt.replaceAll(',', '').replaceAll(' ', '');
    if (state.unitsInSats) clean = clean.replaceAll('.', '');

    final isFiat = state.fiatSelected;
    if (isFiat) {
      final currency = state.currency;
      final fiat = double.tryParse(clean) ?? 0;
      final sats = (fiat / currency!.price!) * 100000000;
      emit(state.copyWith(amount: sats.toInt(), fiatAmt: fiat));
      // _updateShowSend();
      return;
    }

    final isSats = state.unitsInSats;
    final amt = state.getSatsAmount(clean, isSats);
    final currency = state.defaultFiatCurrency;
    final fiatAmt = currency!.price! * (amt / 100000000);

    emit(
      state.copyWith(
        amount: amt,
        fiatAmt: fiatAmt,
        tempAmount: clean,
      ),
    );
    // _updateShowSend();
  }

  void updateAmountDirect(int amt) => emit(state.copyWith(amount: amt));

  void updateAmountError(String err) {
    emit(state.copyWith(errAmount: err));
  }

  void reset() {
    emit(
      state.copyWith(
        amount: 0,
        fiatAmt: 0,
        tempAmount: '',
        errAmount: '',
      ),
    );
  }
}
