import 'dart:convert';

import 'package:bb_mobile/_model/electrum.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/_ui/alert.dart';
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
    final state = change.nextState;
    if (state.networkErrorOpened) return;
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
    emit(network.copyWith(networkErrorOpened: false));
    await Future.delayed(const Duration(milliseconds: 100));
    loadNetworks();
  }

  Future loadNetworks() async {
    if (state.loadingNetworks) return;
    emit(state.copyWith(loadingNetworks: true));

    final networks = state.networks;

    if (networks.isNotEmpty) {
      final selectedNetwork = networks.firstWhere((_) => _.type == state.selectedNetwork);

      emit(
        state.copyWith(
          loadingNetworks: false,
          tempNetworkDetails: selectedNetwork,
          tempNetwork: selectedNetwork.type,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 100));
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

    final selectedNetwork = newNetworks.firstWhere((_) => _.type == state.selectedNetwork);

    emit(
      state.copyWith(
        loadingNetworks: false,
        networks: newNetworks,
        tempNetworkDetails: selectedNetwork,
        tempNetwork: selectedNetwork.type,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 50));

    await setupBlockchain();
  }

  void toggleTestnet() async {
    final isTestnet = state.testnet;
    emit(state.copyWith(testnet: !isTestnet));
    await Future.delayed(const Duration(milliseconds: 50));
    await setupBlockchain();
    await Future.delayed(const Duration(milliseconds: 50));
    homeCubit?.networkChanged(state.testnet ? BBNetwork.Testnet : BBNetwork.Mainnet);
  }

  void updateStopGapAndSave(int gap) async {
    updateTempStopGap(gap);
    await Future.delayed(const Duration(milliseconds: 50));
    networkConfigsSaveClicked();
  }

  void closeNetworkError() async {
    await Future.delayed(const Duration(seconds: 20));
    emit(state.copyWith(networkErrorOpened: false));
  }

  void retryNetwork() async {
    emit(state.copyWith(networkErrorOpened: false));
    await Future.delayed(const Duration(milliseconds: 100));
    setupBlockchain();
  }

  Future setupBlockchain() async {
    emit(state.copyWith(errLoadingNetworks: '', networkConnected: false));
    final isTestnet = state.testnet;
    final selectedNetwork = state.getNetwork();
    if (selectedNetwork == null) return;

    final (blockchain, err) = await walletSync.createBlockChain(
      stopGap: selectedNetwork.stopGap,
      timeout: selectedNetwork.timeout,
      retry: selectedNetwork.retry,
      url: isTestnet ? selectedNetwork.testnet : selectedNetwork.mainnet,
      validateDomain: selectedNetwork.validateDomain,
    );
    if (err != null) {
      if (!state.networkErrorOpened) {
        BBAlert.showErrorAlertPopUp(
          title: err.title ?? '',
          err: err.message,
          onClose: closeNetworkError,
          onRetry: retryNetwork,
        );
      }

      emit(
        state.copyWith(
          blockchain: null,
          errLoadingNetworks: err.toString(),
          networkErrorOpened: true,
        ),
      );
      return;
    }

    emit(state.copyWith(blockchain: blockchain, networkConnected: true));
  }

  void networkTypeTempChanged(ElectrumTypes type) {
    final network = state.networks.firstWhere((_) => _.type == type);

    emit(
      state.copyWith(
        tempNetwork: type,
        tempNetworkDetails: network,
      ),
    );
  }

  void updateTempMainnet(String mainnet) {
    final network = state.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(mainnet: mainnet);
    emit(state.copyWith(tempNetworkDetails: updatedConfig));
  }

  void updateTempTestnet(String testnet) {
    final network = state.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(testnet: testnet);
    emit(state.copyWith(tempNetworkDetails: updatedConfig));
  }

  void updateTempStopGap(int gap) {
    final network = state.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(stopGap: gap);
    emit(state.copyWith(tempNetworkDetails: updatedConfig));
  }

  void updateTempTimeout(int timeout) {
    final network = state.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(timeout: timeout);
    emit(state.copyWith(tempNetworkDetails: updatedConfig));
  }

  void updateTempRetry(int retry) {
    final network = state.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(retry: retry);
    emit(state.copyWith(tempNetworkDetails: updatedConfig));
  }

  void updateTempValidateDomain(bool validateDomain) {
    final network = state.tempNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(validateDomain: validateDomain);
    emit(state.copyWith(tempNetworkDetails: updatedConfig));
  }

  void networkConfigsSaveClicked() async {
    if (state.tempNetwork == null) return;
    final networks = state.networks.toList();
    final tempNetwork = state.tempNetworkDetails!;
    final index = networks.indexWhere((element) => element.type == state.tempNetwork);
    networks.removeAt(index);
    networks.insert(index, state.tempNetworkDetails!);
    emit(state.copyWith(networks: networks, selectedNetwork: tempNetwork.type));
    await Future.delayed(const Duration(milliseconds: 100));
    setupBlockchain();
  }

  void resetTempNetwork() {
    final selectedNetwork = state.getNetwork();
    emit(
      state.copyWith(
        tempNetworkDetails: selectedNetwork,
        tempNetwork: null,
      ),
    );
  }
}
