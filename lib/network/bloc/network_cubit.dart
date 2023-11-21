import 'dart:convert';

import 'package:bb_mobile/_model/electrum.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/network/bloc/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NetworkCubit extends Cubit<NetworkState> {
  NetworkCubit({
    required this.hiveStorage,
    required this.walletSync,
  }) : super(const NetworkState()) {
    init();
  }

  final HiveStorage hiveStorage;
  final WalletSync walletSync;
  HomeCubit? homeCubit;

  @override
  void onChange(Change<NetworkState> change) {
    super.onChange(change);
    hiveStorage.saveValue(
      key: StorageKeys.network,
      value: jsonEncode(change.nextState.toJson()),
    );
  }

  Future<void> init() async {
    Future.delayed(const Duration(milliseconds: 200));
    final (result, err) = await hiveStorage.getValue(StorageKeys.network);
    if (err != null) {
      loadNetworks();

      return;
    }

    final network = NetworkState.fromJson(jsonDecode(result!) as Map<String, dynamic>);
    emit(network);
    await Future.delayed(const Duration(milliseconds: 50));
    loadNetworks();
  }

  void toggleTestnet() async {
    final isTestnet = state.testnet;
    emit(state.copyWith(testnet: !isTestnet));
    await Future.delayed(const Duration(milliseconds: 50));
    await setupBlockchain();
    await Future.delayed(const Duration(milliseconds: 50));
    homeCubit?.networkChanged(state.testnet ? BBNetwork.Testnet : BBNetwork.Mainnet);
  }

  void updateStopGap(int gap) {
    // final network = state.networks
    final network = state.getNetwork();
    if (network == null) return;
    final updatedConfig = network.copyWith(stopGap: gap);
    networkConfigsSaveClicked(updatedConfig);
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
    // loadFees();
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
    emit(state.copyWith(networks: networks));
    await Future.delayed(const Duration(milliseconds: 50));
    setupBlockchain();
  }

  void networkTypeTempChanged(ElectrumTypes types) => emit(state.copyWith(tempNetwork: types));

  void removeTempNetwork() => emit(state.copyWith(tempNetwork: null));
}
