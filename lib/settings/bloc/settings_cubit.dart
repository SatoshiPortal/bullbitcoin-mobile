import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/_model/currency.dart';
import 'package:bb_mobile/_model/electrum.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
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
      // first time maybe
      loadNetworks();
      return;
    }

    final settings = SettingsState.fromJson(jsonDecode(result!) as Map<String, dynamic>);
    emit(settings);
    await Future.delayed(const Duration(milliseconds: 50));
    loadNetworks();
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

  void toggleTestnet() async {
    final isTestnet = state.testnet;
    emit(state.copyWith(testnet: !isTestnet));
    await Future.delayed(const Duration(milliseconds: 50));
    setupBlockchain();
    homeCubit?.clearSelectedWallet();
  }

  void toggleDefaultRBF() {
    emit(state.copyWith(defaultRBF: !state.defaultRBF));
  }

  void changeLanguage(String language) {
    emit(state.copyWith(language: language));
  }

  void updateStopGap(int gap) {
    // final network = state.networks
    final network = state.getNetwork();
    if (network == null) return;
    final updatedConfig = network.copyWith(stopGap: gap);
    networkConfigsSaveClicked(updatedConfig);
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
    // final (eur, _) = await bbAPI.getExchangeRate(toCurrency: 'EUR');
    final (crc, _) = await bbAPI.getExchangeRate(toCurrency: 'CRC');
    final (inr, _) = await bbAPI.getExchangeRate(toCurrency: 'INR');

    final results = [
      if (cad != null) cad,
      if (usd != null) usd,
      // if (eur != null) eur,
      if (crc != null) crc,
      if (inr != null) inr,
    ];

    emit(
      state.copyWith(
        currency: results.first,
        currencyList: results,
        loadingCurrency: false,
        lastUpdatedCurrency: DateTime.now(),
      ),
    );

    if (state.currency != null) {
      final currency = results.firstWhere((element) => element.name == state.currency!.name);
      emit(state.copyWith(currency: currency));
    }
  }

  Future setupBlockchain() async {
    emit(state.copyWith(errLoadingNetworks: '', networkConnected: false));
    final isTestnet = state.testnet;
    final selectedNetwork = state.getNetwork();
    if (selectedNetwork == null) return;
    // final selectedNetwork = state.networks[state.selectedNetwork];

    final (blockchain, err) = await walletSync.createBlockChain(
      stopGap: selectedNetwork.stopGap,
      timeout: selectedNetwork.timeout,
      retry: selectedNetwork.retry,
      url: isTestnet ? selectedNetwork.testnet : selectedNetwork.mainnet,
      validateDomain: selectedNetwork.validateDomain,
    );
    if (err != null) {
      emit(
        state.copyWith(
          blockchain: null,
          errLoadingNetworks: err.toString(),
        ),
      );
      return;
    }

    emit(state.copyWith(blockchain: blockchain, networkConnected: true));
    loadFees();
  }

  Future loadNetworks() async {
    if (state.loadingNetworks) return;
    emit(state.copyWith(loadingNetworks: true));

    final networks = state.networks;

    if (networks.isNotEmpty) {
      emit(state.copyWith(loadingNetworks: false));
      setupBlockchain();
      return;
    }

    final newNetworks = [
      const ElectrumNetwork.defaultElectrum(),
      const ElectrumNetwork.bullbitcoin(),
      const ElectrumNetwork.custom(
        mainnet: 'ssl://$bbelectrum:50002',
        testnet: 'ssl://$bbelectrum:60002',
      ),
    ];

    emit(
      state.copyWith(
        loadingNetworks: false,
        networks: newNetworks,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 50));

    await setupBlockchain();
  }

  void changeNetwork(ElectrumTypes electrumType) {
    emit(state.copyWith(selectedNetwork: electrumType));
    setupBlockchain();
  }

  void networkConfigsSaveClicked(ElectrumNetwork network) async {
    if (state.tempNetwork != null) {
      emit(state.copyWith(selectedNetwork: state.tempNetwork!));
      await Future.delayed(const Duration(milliseconds: 50));
      emit(state.copyWith(tempNetwork: null));
    }
    final networks = state.networks.toList();
    final index = networks.indexWhere((element) => element.type == network.type);
    networks.removeAt(index);
    networks.insert(index, network);
    // networks.removeAt(state.selectedNetwork);
    // networks.insert(state.selectedNetwork, network);
    emit(state.copyWith(networks: networks));
    await Future.delayed(const Duration(milliseconds: 50));
    setupBlockchain();
  }

  void networkTypeTempChanged(ElectrumTypes types) => emit(state.copyWith(tempNetwork: types));

  void removeTempNetwork() => emit(state.copyWith(tempNetwork: null));

  void loadFees() async {
    emit(state.copyWith(loadingFees: true, errLoadingFees: ''));

    final (fees, err) = await mempoolAPI.getFees(state.testnet);
    if (err != null) {
      emit(
        state.copyWith(
          errLoadingFees: err.toString(),
          loadingFees: false,
        ),
      );
      return;
    }

    // final blockchain = state.blockchain;
    // if (blockchain == null) throw 'No Blockchain';

    // final fast = await blockchain.estimateFee(1);
    // final medium = await blockchain.estimateFee(6);
    // final slow = await blockchain.estimateFee(12);

    // final fees = [
    //   fast.asSatPerVb().round(),
    //   medium.asSatPerVb().round(),
    //   slow.asSatPerVb().round(),
    // ];

    emit(
      state.copyWith(
        feesList: fees,
        loadingFees: false,
      ),
    );
  }

  void updateManualFees(String fees) async {
    final feesInDouble = int.tryParse(fees);
    if (feesInDouble == null) {
      emit(state.copyWith(fees: 000, selectedFeesOption: 2));
      await Future.delayed(const Duration(milliseconds: 50));
      emit(state.copyWith(fees: null));
      return;
    }
    emit(state.copyWith(fees: feesInDouble, selectedFeesOption: 4));
    checkMinimumFees();
  }

  void feeOptionSelected(int index) {
    emit(state.copyWith(selectedFeesOption: index));
    checkMinimumFees();
  }

  void checkFees() {
    if (state.selectedFeesOption == 4 && (state.fees == null || state.fees == 0))
      feeOptionSelected(2);
  }

  void checkMinimumFees() {
    final minFees = state.feesList!.last;

    if (state.fees != null && state.fees! < minFees && state.selectedFeesOption == 4)
      emit(
        state.copyWith(
          errLoadingFees:
              "The selected fee is below the Bitcoin Network's minimum relay fee. Your transaction will likely never confirm. Please select a higher fee than $minFees sats/vbyte .",
          selectedFeesOption: 2,
        ),
      );
    else
      emit(state.copyWith(errLoadingFees: ''));
  }

  ElectrumTypes? networkFromString(String text) {
    final network = text.toLowerCase().replaceAll(' ', '');
    switch (network) {
      case 'blockstream':
        return ElectrumTypes.blockstream;
      case 'bullbitcoin':
        return ElectrumTypes.bullbitcoin;
      case 'custom':
        return ElectrumTypes.custom;
      default:
        return null;
    }
  }

  void clearErrors() async {
    emit(
      state.copyWith(
        errLoadingCurrency: '',
        errLoadingFees: '',
        errLoadingLanguage: '',
        errLoadingNetworks: '',
      ),
    );
  }
}
