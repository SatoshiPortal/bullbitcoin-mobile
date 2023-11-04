import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/_model/currency.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_state.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required this.hiveStorage,
    required this.bbAPI,
    required this.mempoolAPI,
    required this.walletSync,
  }) : super(const SettingsState()) {
    init();
    loadCurrencies();
  }

  final HiveStorage hiveStorage;
  final BullBitcoinAPI bbAPI;
  final MempoolAPI mempoolAPI;
  final WalletSync walletSync;

  HomeCubit? homeCubit;

  Timer? _timer;

  @override
  void onChange(Change<SettingsState> change) {
    super.onChange(change);
    hiveStorage.saveValue(
      key: StorageKeys.settings,
      value: jsonEncode(change.nextState.toJson()),
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }

  Future<void> init() async {
    Future.delayed(const Duration(milliseconds: 200));
    final (result, err) = await hiveStorage.getValue(StorageKeys.settings);
    if (err != null) {
      return;
    }

    final settings = SettingsState.fromJson(jsonDecode(result!) as Map<String, dynamic>);
    emit(settings);
  }

  void toggleUnitsInSats() {
    emit(state.copyWith(unitsInSats: !state.unitsInSats));
  }

  void toggleNotifications() {
    emit(state.copyWith(notifications: !state.notifications));
  }

  void togglePrivacyView() {
    emit(state.copyWith(privacyView: !state.privacyView));
  }

  void toggleDefaultRBF() {
    emit(state.copyWith(defaultRBF: !state.defaultRBF));
  }

  void changeLanguage(String language) {
    emit(state.copyWith(language: language));
  }

  void updateReloadWalletTimer(int value) {
    emit(state.copyWith(reloadWalletTimer: value));
    loadTimer();
  }

  void loadTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: state.reloadWalletTimer), (timer) {
      homeCubit?.state.selectedWalletCubit?.add(SyncWallet());
    });
  }

  void changeCurrency(Currency currency) {
    emit(state.copyWith(currency: currency));
  }

  void loadCurrencies() async {
    emit(state.copyWith(loadingCurrency: true));
    final (cad, _) = await bbAPI.getExchangeRate(toCurrency: 'CAD');
    final (usd, _) = await bbAPI.getExchangeRate(toCurrency: 'USD');

    final (crc, _) = await bbAPI.getExchangeRate(toCurrency: 'CRC');
    final (inr, _) = await bbAPI.getExchangeRate(toCurrency: 'INR');

    final results = [
      if (cad != null) cad,
      if (usd != null) usd,
      if (crc != null) crc,
      if (inr != null) inr,
    ];

    emit(
      state.copyWith(
        currency: results.isNotEmpty ? results.first : state.currency,
        currencyList: results.isEmpty ? results : state.currencyList,
        loadingCurrency: false,
        lastUpdatedCurrency: DateTime.now(),
      ),
    );

    if (state.currency != null) {
      final currency = results.firstWhere(
        (_) => _.name == state.currency!.name,
        orElse: () => state.currency!,
      );
      emit(state.copyWith(currency: currency));
      if (results.isEmpty && state.currencyList == null)
        emit(state.copyWith(currencyList: [currency]));
    }
  }
}
