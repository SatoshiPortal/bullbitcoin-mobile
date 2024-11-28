import 'dart:convert';

import 'package:bb_mobile/_model/network.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/electrum_test.dart';
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
    // final state = change.nextState;
    // if (state.networkErrorOpened) return;
    _hiveStorage.saveValue(
      key: StorageKeys.network,
      value: jsonEncode(
        change.nextState
            .copyWith(
              networkErrorOpened: false,
            )
            .toJson(),
      ),
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
          networks.firstWhere((e) => e.type == state.selectedNetwork);

      emit(
        state.copyWith(
          loadingNetworks: false,
          tempNetworkDetails: selectedNetwork,
          tempNetwork: selectedNetwork.type,
          selectedNetwork: selectedNetwork.type,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 200));
      setupBlockchain(isLiquid: false);
    } else {
      final newNetworks = [
        const ElectrumNetwork.defaultElectrum(),
        const ElectrumNetwork.bullbitcoin(),
        const ElectrumNetwork.custom(
          mainnet: 'ssl://$bbelectrumMain',
          testnet: 'ssl://$openelectrumTest',
        ),
      ];

      final selectedNetwork = newNetworks[2];
      //.firstWhere((_) => _.type == state.selectedNetwork);
      emit(
        state.copyWith(
          networks: newNetworks,
          tempNetworkDetails: selectedNetwork,
          tempNetwork: selectedNetwork.type,
          selectedNetwork: selectedNetwork.type,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 200));
      await setupBlockchain(isLiquid: false);
    }

    if (liqNetworks.isNotEmpty) {
      var selectedNetwork =
          liqNetworks.firstWhere((e) => e.type == state.selectedLiquidNetwork);
      final updatedLiqNetworks = liqNetworks.toList();

      if (liqNetworks.length == 2) {
        updatedLiqNetworks.insert(1, const LiquidElectrumNetwork.bullbitcoin());
        selectedNetwork = updatedLiqNetworks[1];
      }
      emit(
        state.copyWith(
          loadingNetworks: false,
          tempLiquidNetworkDetails: selectedNetwork,
          tempLiquidNetwork: selectedNetwork.type,
          liquidNetworks: updatedLiqNetworks,
          selectedLiquidNetwork: selectedNetwork.type,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 200));
      setupBlockchain(isLiquid: true);
    } else {
      final newLiqNetworks = [
        const LiquidElectrumNetwork.blockstream(),
        const LiquidElectrumNetwork.bullbitcoin(),
        const LiquidElectrumNetwork.custom(
          mainnet: liquidElectrumUrl,
          testnet: liquidElectrumTestUrl,
        ),
      ];
      // final selectedLiqNetwork = newLiqNetworks
      //     .firstWhere((_) => _.type == state.selectedLiquidNetwork);

      final selectedLiqNetwork = newLiqNetworks[1];

      emit(
        state.copyWith(
          liquidNetworks: newLiqNetworks,
          tempLiquidNetworkDetails: selectedLiqNetwork,
          tempLiquidNetwork: selectedLiqNetwork.type,
          selectedLiquidNetwork: selectedLiqNetwork.type,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 200));
      setupBlockchain(isLiquid: true);
    }

    emit(state.copyWith(loadingNetworks: false));
  }

  Future<void> toggleTestnet() async {
    final isTestnet = state.testnet;
    await Future.delayed(const Duration(milliseconds: 50));
    try {
      await setupBlockchain(isTestnetLocal: !isTestnet);
    } catch (e) {
      emit(state.copyWith(errLoadingNetworks: e.toString()));
    }
    // await Future.delayed(const Duration(milliseconds: 50));
    emit(state.copyWith(testnet: !isTestnet));
    // homeCubit?.networkChanged(state.testnet ? BBNetwork.Testnet : BBNetwork.Mainnet);
  }

  Future<void> updateStopGapAndSave(int gap) async {
    updateTempStopGap(gap);
    await Future.delayed(const Duration(milliseconds: 50));
    networkConfigsSaveClicked(isLiq: false);
  }

  Future<void> closeNetworkError() async {
    emit(state.copyWith(goToSettings: true));
    await Future.delayed(const Duration(milliseconds: 200));
    emit(state.copyWith(goToSettings: false));
    await Future.delayed(const Duration(seconds: 20));
    emit(state.copyWith(networkErrorOpened: false));
  }

  Future<void> retryNetwork() async {
    emit(state.copyWith(networkErrorOpened: false));
    await Future.delayed(const Duration(milliseconds: 100));
    setupBlockchain();
  }

  Future setupBlockchain({bool? isLiquid, bool? isTestnetLocal}) async {
    emit(state.copyWith(errLoadingNetworks: '', networkConnected: false));
    final isTestnet = isTestnetLocal ?? state.testnet;

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
          emit(state.copyWith(networkErrorOpened: true));
          BBAlert.showErrorAlertPopUp(
            title: errBitcoin.title ?? '',
            err: errBitcoin.message,
            onClose: closeNetworkError,
            okButtonText: 'Change server',
            onRetry: retryNetwork,
          );
          await Future.delayed(const Duration(seconds: 10));
          emit(state.copyWith(networkErrorOpened: false));
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
            okButtonText: 'Change server',
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
    final network = state.networks.firstWhere((e) => e.type == type);

    emit(
      state.copyWith(
        tempNetwork: type,
        tempNetworkDetails: network,
      ),
    );
  }

  void liqNetworkTypeTempChanged(LiquidElectrumTypes type) {
    final network = state.liquidNetworks.firstWhere((e) => e.type == type);

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

  String _checkURL(String url) {
    if (!url.contains('://')) return 'ssl://$url';
    return url;
  }

  bool isTorAddress(String url) {
    if (url.isEmpty) return false;

    final split = url.split(':');
    String cleanUrl = split.length > 1
        ? split[1]
        : split[0]; // remove uri schema and port number

    cleanUrl = cleanUrl.split('//').last; // to remove the slashes

    final torRegex = RegExp(r'^([a-z2-7]{16}|[a-zA-Z2-7]{56})\.onion$');
    return torRegex.hasMatch(cleanUrl);
  }

  String networkLoadError(String url) {
    if (isTorAddress(url)) {
      return "Tor isn't supported";
    }
    return '';
  }

  Future<void> networkConfigsSaveClicked({required bool isLiq}) async {
    emit(state.copyWith(errLoadingNetworks: '', networkConnected: false));
    if (!isLiq) {
      if (state.tempNetwork == null) return;
      final networks = state.networks.toList();
      final tempNetwork = state.tempNetworkDetails!;
      final checkedTempNetworkDetails = tempNetwork.copyWith(
        mainnet: _checkURL(tempNetwork.mainnet),
        testnet: _checkURL(tempNetwork.testnet),
      );

      // Local validation
      final sslRegex =
          RegExp(r'^ssl:\/\/([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})\:[0-9]{2,5}$');
      if (!sslRegex.hasMatch(tempNetwork.mainnet)) {
        final String error = networkLoadError(tempNetwork.mainnet);
        final String formattedError = error.isNotEmpty ? (': $error') : '';
        emit(
          state.copyWith(
            errLoadingNetworks: 'Invalid mainnet electrum URL$formattedError',
          ),
        );
        return;
      }
      if (!sslRegex.hasMatch(tempNetwork.testnet)) {
        final String error = networkLoadError(tempNetwork.testnet);
        final String formattedError = error.isNotEmpty ? ': $error' : '';
        emit(
          state.copyWith(
            errLoadingNetworks: 'Invalid testnet electrum URL$formattedError',
          ),
        );
        return;
      }

      // Connection test with electrum
      final mainnetElectrumLive = await isElectrumLive(tempNetwork.mainnet);
      if (!mainnetElectrumLive) {
        emit(
          state.copyWith(
            errLoadingNetworks:
                'Pls check mainnet electrum URL. Cannot connect to electrum',
          ),
        );
        return;
      }
      final testnetElectrumLive = await isElectrumLive(tempNetwork.testnet);
      if (!testnetElectrumLive) {
        emit(
          state.copyWith(
            errLoadingNetworks:
                'Pls check testnet electrum URL. Cannot connect to electrum',
          ),
        );
        return;
      }

      final index =
          networks.indexWhere((element) => element.type == state.tempNetwork);
      networks.removeAt(index);
      networks.insert(index, checkedTempNetworkDetails);
      emit(
        state.copyWith(
          networks: networks,
          selectedNetwork: tempNetwork.type,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 100));
      setupBlockchain(isLiquid: false);
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
    setupBlockchain(isLiquid: true);
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
