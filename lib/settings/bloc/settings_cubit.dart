import 'dart:async';
import 'dart:convert';

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

  void updateHomeLayout(int value) => emit(state.copyWith(homeLayout: value));

  void loadTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: state.reloadWalletTimer), (timer) {
      homeCubit?.state.selectedWalletCubit?.add(SyncWallet());
    });
  }
}
