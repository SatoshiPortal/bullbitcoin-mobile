import 'dart:convert';

import 'package:bb_mobile/_model/network.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_pkg/wallet/network.dart';
import 'package:bb_mobile/_ui/alert.dart';
import 'package:bb_mobile/network/bloc/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NetworkCubit extends Cubit<NetworkState> {
  NetworkCubit({
    required HiveStorage hiveStorage,
    required WalletNetwork walletNetwork,
  })  : _walletNetwork = walletNetwork,
        _hiveStorage = hiveStorage,
        super(const NetworkState()) {
    init();
  }

  final HiveStorage _hiveStorage;
  final WalletNetwork _walletNetwork;

  @override
  void onChange(Change<NetworkState> change) {
    super.onChange(change);
    final state = change.nextState;
    if (state.networkErrorOpened) return;
    _hiveStorage.saveValue(
      key: StorageKeys.network,
      value: jsonEncode(change.nextState.toJson()),
    );
  }

  Future<void> init() async {
    Future.delayed(const Duration(milliseconds: 200));
    final (result, err) = await _hiveStorage.getValue(StorageKeys.network);
    if (err != null) {
      loadNetworks();
      return;
    }

    final network =
        NetworkState.fromJson(jsonDecode(result!) as Map<String, dynamic>);
    emit(network.copyWith(networkErrorOpened: false));
    await Future.delayed(const Duration(milliseconds: 100));
    loadNetworks();
  }

  Future loadNetworks() async {
    if (state.loadingNetworks) return;
    emit(state.copyWith(loadingNetworks: true));

    final networks = state.networks;
    final liqNetworks = state.liquidNetworks;

    if (networks.isNotEmpty) {
      final selectedNetwork =
          networks.firstWhere((_) => _.type == state.selectedNetwork);

      emit(
        state.copyWith(
          loadingNetworks: false,
          tempNetworkDetails: selectedNetwork,
          tempNetwork: selectedNetwork.type,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 100));
      setupBlockchain(false);
    } else {
      final newNetworks = [
        const ElectrumNetwork.defaultElectrum(),
        const ElectrumNetwork.bullbitcoin(),
        const ElectrumNetwork.custom(
          mainnet: 'ssl://$bbelectrum:50002',
          testnet: 'ssl://$openelectrum:60002',
        ),
      ];

      final selectedNetwork = newNetworks[2];
      //.firstWhere((_) => _.type == state.selectedNetwork);
      emit(
        state.copyWith(
          networks: newNetworks,
          tempNetworkDetails: selectedNetwork,
          tempNetwork: selectedNetwork.type,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      await setupBlockchain(false);
    }

    if (liqNetworks.isNotEmpty) {
      final selectedNetwork =
          liqNetworks.firstWhere((_) => _.type == state.selectedLiquidNetwork);

      emit(
        state.copyWith(
          loadingNetworks: false,
          tempLiquidNetworkDetails: selectedNetwork,
          tempLiquidNetwork: selectedNetwork.type,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 100));
      setupBlockchain(true);
    } else {
      final newLiqNetworks = [
        const LiquidElectrumNetwork.blockstream(),
        const LiquidElectrumNetwork.custom(
          mainnet: liquidElectrumUrl,
          testnet: liquidElectrumTestUrl,
        ),
      ];
      final selectedLiqNetwork = newLiqNetworks
          .firstWhere((_) => _.type == state.selectedLiquidNetwork);

      emit(
        state.copyWith(
          liquidNetworks: newLiqNetworks,
          tempLiquidNetworkDetails: selectedLiqNetwork,
          tempLiquidNetwork: selectedLiqNetwork.type,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 100));
      setupBlockchain(true);
    }

    emit(state.copyWith(loadingNetworks: false));
  }

  void toggleTestnet() async {
    final isTestnet = state.testnet;
    emit(state.copyWith(testnet: !isTestnet));
    await Future.delayed(const Duration(milliseconds: 50));
    await setupBlockchain(null);
    await Future.delayed(const Duration(milliseconds: 50));
    // homeCubit?.networkChanged(state.testnet ? BBNetwork.Testnet : BBNetwork.Mainnet);
  }

  void updateStopGapAndSave(int gap) async {
    updateTempStopGap(gap);
    await Future.delayed(const Duration(milliseconds: 50));
    networkConfigsSaveClicked(isLiq: false);
  }

  void closeNetworkError() async {
    await Future.delayed(const Duration(seconds: 20));
    emit(state.copyWith(networkErrorOpened: false));
  }

  void retryNetwork() async {
    emit(state.copyWith(networkErrorOpened: false));
    await Future.delayed(const Duration(milliseconds: 100));
    setupBlockchain(null);
  }

  Future setupBlockchain(bool? isLiquid) async {
    emit(state.copyWith(errLoadingNetworks: '', networkConnected: false));
    final isTestnet = state.testnet;

    if (isLiquid == null || !isLiquid) {
      final selectedNetwork = state.getNetwork();
      if (selectedNetwork == null) return;

      final errBitcoin = await _walletNetwork.createBlockChain(
        isTestnet: isTestnet,
        stopGap: selectedNetwork.stopGap,
        timeout: selectedNetwork.timeout,
        retry: selectedNetwork.retry,
        url: isTestnet ? selectedNetwork.testnet : selectedNetwork.mainnet,
        validateDomain: selectedNetwork.validateDomain,
      );
      if (errBitcoin != null) {
        if (!state.networkErrorOpened) {
          BBAlert.showErrorAlertPopUp(
            title: errBitcoin.title ?? '',
            err: errBitcoin.message,
            onClose: closeNetworkError,
            onRetry: retryNetwork,
          );
        }
        return;
      }
    }

    if (isLiquid == null || isLiquid) {
      final selectedLiqNetwork = state.getLiquidNetwork();
      if (selectedLiqNetwork == null) return;

      final errLiquid = await _walletNetwork.createBlockChain(
        url:
            isTestnet ? selectedLiqNetwork.testnet : selectedLiqNetwork.mainnet,
        isTestnet: isTestnet,
      );
      if (errLiquid != null) {
        if (!state.networkErrorOpened) {
          BBAlert.showErrorAlertPopUp(
            title: errLiquid.title ?? '',
            err: errLiquid.message,
            onClose: closeNetworkError,
            onRetry: retryNetwork,
          );
        }

        emit(
          state.copyWith(
            errLoadingNetworks: errLiquid.toString(),
            networkErrorOpened: true,
          ),
        );
      }
    }

    emit(state.copyWith(networkConnected: true));
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

  void liqNetworkTypeTempChanged(LiquidElectrumTypes type) {
    final network = state.liquidNetworks.firstWhere((_) => _.type == type);

    emit(
      state.copyWith(
        tempLiquidNetwork: type,
        tempLiquidNetworkDetails: network,
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

  void updateTempLiquidMainnet(String mainnet) {
    final network = state.tempLiquidNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(mainnet: mainnet);
    emit(state.copyWith(tempLiquidNetworkDetails: updatedConfig));
  }

  void updateTempLiquidTestnet(String testnet) {
    final network = state.tempLiquidNetworkDetails;
    if (network == null) return;
    final updatedConfig = network.copyWith(testnet: testnet);
    emit(state.copyWith(tempLiquidNetworkDetails: updatedConfig));
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

  void networkConfigsSaveClicked({required bool isLiq}) async {
    if (!isLiq) {
      if (state.tempNetwork == null) return;
      final networks = state.networks.toList();
      final tempNetwork = state.tempNetworkDetails!;
      final index =
          networks.indexWhere((element) => element.type == state.tempNetwork);
      networks.removeAt(index);
      networks.insert(index, state.tempNetworkDetails!);
      emit(
        state.copyWith(
          networks: networks,
          selectedNetwork: tempNetwork.type,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 100));
      setupBlockchain(false);
      return;
    }

    if (state.tempLiquidNetwork == null) return;
    final networks = state.liquidNetworks.toList();
    final tempNetwork = state.tempLiquidNetworkDetails!;
    final index = networks
        .indexWhere((element) => element.type == state.tempLiquidNetwork);
    networks.removeAt(index);
    networks.insert(index, state.tempLiquidNetworkDetails!);
    emit(
      state.copyWith(
        liquidNetworks: networks,
        selectedLiquidNetwork: tempNetwork.type,
      ),
    );
    await Future.delayed(const Duration(milliseconds: 100));
    setupBlockchain(true);
  }

  void resetTempNetwork() {
    final selectedNetwork = state.getNetwork();
    final selectedLiquidNetwork = state.getLiquidNetwork();
    emit(
      state.copyWith(
        tempNetworkDetails: selectedNetwork,
        tempNetwork: null,
        tempLiquidNetwork: null,
        tempLiquidNetworkDetails: selectedLiquidNetwork,
      ),
    );
  }
}
